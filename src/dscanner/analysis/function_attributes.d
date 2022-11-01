//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.function_attributes;

import dscanner.analysis.base;
import std.stdio;
import dsymbol.scope_;

import dscanner.analysis.helpers;
import dmd.astenums : STC, MODFlags;
import dmd.lexer : Lexer;
import dscanner.utils : readFile;
import dmd.tokens;
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
extern(C++) class FunctionAttributeCheck(AST) : BaseAnalyzerDmd!AST
{
	mixin AnalyzerInfo!"function_attribute_check";
	alias visit = BaseAnalyzerDmd!AST.visit;

	extern(D) this(string fileName)
	{
		super(fileName);
		this.inInterface = false;
	}

	override void visit(AST.InterfaceDeclaration id)
	{
		this.inInterface = true;
		super.visit(id);
		this.inInterface = false;
	}

	string getStorage(AST.TypeFunction tf)
	{
		if (tf.mod & MODFlags.const_)
			return "const";

		if (tf.mod & MODFlags.immutable_)
			return "immutable";

		if (tf.mod & MODFlags.wild)
			return "inout";

		return null;
	}

	override void visit(AST.FuncDeclaration fd)
	{
		if (!fd.type)
		{
			super.visit(fd);
			return;
		}

		auto tf = fd.type.isTypeFunction();

		if (!tf)
		{
			super.visit(fd);
			return;
		}

		string storageTok = getStorage(tf);

		if (tf.isproperty() && tf.parameterList.parameters.length == 0 && !storageTok)
			addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
				"Zero-parameter '@property' function should be marked 'const', 'inout', or 'immutable'.");
	
		if ((fd.storage_class & STC.abstract_) && inInterface)
			addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
				"'abstract' attribute is redundant in interface declarations");

		if (storageTok)
		{
			bool foundConst = false;
			auto bytes = readFile(fileName);
			
			bytes ~= "\0";
			bytes = bytes[fd.loc.fileOffset .. $];

			scope lexer = new Lexer(null, cast(char*) bytes, 0, bytes.length, 0, 0);
			TOK nextTok;
			lexer.nextToken();

			do {
				if (lexer.token.value == TOK.const_ || lexer.token.value == TOK.immutable_ || lexer.token.value == TOK.inout_)
					foundConst = true;
			
				nextTok = lexer.nextToken();
			} while(nextTok != TOK.leftCurly && nextTok != TOK.endOfFile);

			if (!foundConst)
				addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
					format(
							"'%s' is not an attribute of the return type." ~
							" Place it after the parameter list to clarify.",
							storageTok
						));
		}

		super.visit(fd);
	}

private:
	bool inInterface;
	enum string KEY = "dscanner.confusing.function_attributes";
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import std.file : remove, exists;
	import std.stdio : File;

	StaticAnalysisConfig sac = disabledConfig();
	sac.function_attribute_check = Check.enabled;

	assertAnalyzerWarningsDMD(q{
		class C
		{
			bool foo() @property { return true; } // [warn]: Zero-parameter '@property' function should be marked 'const', 'inout', or 'immutable'.

			const void foo() {} // [warn]: 'const' is not an attribute of the return type. Place it after the parameter list to clarify.
		
			void goo() const {} // OK

			bool g() @property const { return true; } // OK

		}

		interface I
		{
			abstract void foo(); // [warn]: 'abstract' attribute is redundant in interface declarations
		}
	}c, sac);

	stderr.writeln("Unittest for ObjectConstCheck passed.");
}
