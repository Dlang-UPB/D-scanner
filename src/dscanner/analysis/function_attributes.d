//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.function_attributes;

import dscanner.analysis.base;
import dmd.astenums : STC, MOD, MODFlags;
import std.string : format;

/**
 * Prefer
 * ---
 * int getStuff() const {}
 * ---
 * to
 * ---
 * const int getStuff() {}
 * ---
 */
extern (C++) class FunctionAttributeCheck(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"function_attribute_check";

	private enum KEY = "dscanner.confusing.function_attributes";
	private enum CONST_MSG = "Zero-parameter '@property' function should be marked 'const', 'inout', or 'immutable'.";
	private enum ABSTRACT_MSG = "'abstract' attribute is redundant in interface declarations";
	private enum RETURN_MSG = "'%s' is not an attribute of the return type. Place it after the parameter list to clarify.";

	private bool inInterface = false;

	extern (D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.InterfaceDeclaration id)
	{
		this.inInterface = true;
		super.visit(id);
		this.inInterface = false;
	}

	override void visit(AST.FuncDeclaration fd)
	{
		super.visit(fd);

		if (fd.type is null)
			return;

		auto tf = fd.type.isTypeFunction();
		if (tf is null)
			return;

		immutable ulong lineNum = cast(ulong) fd.loc.linnum;
		immutable ulong charNum = cast(ulong) fd.loc.charnum;
		immutable bool isAbstract = (fd.storage_class & STC.abstract_) > 0;
		immutable bool isStatic = (fd.storage_class & STC.static_) > 0;

		if (isAbstract && inInterface)
			addErrorMessage(lineNum, charNum, KEY, ABSTRACT_MSG);

		string storageTok = getConstLikeStorage(tf.mod);

		if (storageTok is null)
		{
			if (!isStatic && tf.isproperty() && tf.parameterList.parameters.length == 0)
				addErrorMessage(lineNum, charNum, KEY, CONST_MSG);
		}
		else
		{
			if (!hasConstLikeAttribute(cast(ulong) fd.loc.fileOffset))
				addErrorMessage(lineNum, charNum, KEY, RETURN_MSG.format(storageTok));
		}
	}

	private extern (D) string getConstLikeStorage(MOD mod)
	{
		if (mod & MODFlags.const_)
			return "const";

		if (mod & MODFlags.immutable_)
			return "immutable";

		if (mod & MODFlags.wild)
			return "inout";

		return null;
	}

	private bool hasConstLikeAttribute(ulong fileOffset)
	{
		import dscanner.utils : readFile;
		import dmd.errorsink : ErrorSinkNull;
		import dmd.globals : global;
		import dmd.lexer : Lexer;
		import dmd.tokens : TOK;

		auto bytes = readFile(fileName) ~ '\0';
		bytes = bytes[fileOffset .. $];

		__gshared ErrorSinkNull errorSinkNull;
		if (!errorSinkNull)
			errorSinkNull = new ErrorSinkNull;

		scope lexer = new Lexer(null, cast(char*) bytes, 0, bytes.length, 0, 0, errorSinkNull, &global.compileEnv);
		TOK nextTok = lexer.nextToken();

		do
		{
			if (nextTok == TOK.const_ || nextTok == TOK.immutable_ || nextTok == TOK.inout_)
				return true;

			nextTok = lexer.nextToken();
		}
		while (nextTok != TOK.leftCurly && nextTok != TOK.endOfFile);

		return false;
	}
}

unittest
{
	import dscanner.analysis.config : Check, disabledConfig, StaticAnalysisConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;
	import std.stdio : stderr;

	StaticAnalysisConfig sac = disabledConfig();
	sac.function_attribute_check = Check.enabled;

	assertAnalyzerWarningsDMD(q{
		// int foo() @property { return 0; }

		class ClassName {
			const int confusingConst() { return 0; } // [warn]: 'const' is not an attribute of the return type. Place it after the parameter list to clarify.
			int bar() @property { return 0; } // [warn]: Zero-parameter '@property' function should be marked 'const', 'inout', or 'immutable'.
			static int barStatic() @property { return 0; }
			int barConst() const @property { return 0; }
		}

		struct StructName {
			int bar() @property { return 0; } // [warn]: Zero-parameter '@property' function should be marked 'const', 'inout', or 'immutable'.
			static int barStatic() @property { return 0; }
			int barConst() const @property { return 0; }
		}

		union UnionName {
			int bar() @property { return 0; } // [warn]: Zero-parameter '@property' function should be marked 'const', 'inout', or 'immutable'.
			static int barStatic() @property { return 0; }
			int barConst() const @property { return 0; }
		}

		interface InterfaceName {
			int bar() @property; // [warn]: Zero-parameter '@property' function should be marked 'const', 'inout', or 'immutable'.
			static int barStatic() @property { return 0; }
			int barConst() const @property;
			abstract int method(); // [warn]: 'abstract' attribute is redundant in interface declarations
		}
	}c, sac);

/* TODO: Fix AutoFix
	assertAutoFix(q{
		int foo() @property { return 0; }

		class ClassName {
			const int confusingConst() { return 0; } // fix:0
			const int confusingConst() { return 0; } // fix:1

			int bar() @property { return 0; } // fix:0
			int bar() @property { return 0; } // fix:1
			int bar() @property { return 0; } // fix:2
		}

		struct StructName {
			int bar() @property { return 0; } // fix:0
		}

		union UnionName {
			int bar() @property { return 0; } // fix:0
		}

		interface InterfaceName {
			int bar() @property; // fix:0

			abstract int method(); // fix
		}
	}c, q{
		int foo() @property { return 0; }

		class ClassName {
			int confusingConst() const { return 0; } // fix:0
			const(int) confusingConst() { return 0; } // fix:1

			int bar() const @property { return 0; } // fix:0
			int bar() inout @property { return 0; } // fix:1
			int bar() immutable @property { return 0; } // fix:2
		}

		struct StructName {
			int bar() const @property { return 0; } // fix:0
		}

		union UnionName {
			int bar() const @property { return 0; } // fix:0
		}

		interface InterfaceName {
			int bar() const @property; // fix:0

			int method(); // fix
		}
	}c, sac);
	*/

	stderr.writeln("Unittest for ObjectConstCheck passed.");
}
