// Distributed under the Boost Software License, Version 1.0.
//	  (See accompanying file LICENSE_1_0.txt or copy at
//			http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.if_constraints_indent;

import dscanner.analysis.base;
import dmd.tokens : Token, TOK;
import std.typecons : Tuple, tuple;

/**
Checks whether all if constraints have the same indention as their declaration.
*/
extern (C++) class IfConstraintsIndentCheck(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"if_constraints_indent";

	private enum string KEY = "dscanner.style.if_constraints_indent";
	private enum string MSG = "If constraints should have the same indentation as the function";

	private Token[] tokens;
	alias FileOffset = uint;
	private uint[FileOffset] tokenIndexes;

	extern (D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
		lexFile();
	}

	private void lexFile()
	{
		import dscanner.utils : readFile;
		import dmd.errorsink : ErrorSinkNull;
		import dmd.globals : global;
		import dmd.lexer : Lexer;

		auto bytes = readFile(fileName) ~ '\0';

		__gshared ErrorSinkNull errorSinkNull;
		if (!errorSinkNull)
			errorSinkNull = new ErrorSinkNull;

		scope lexer = new Lexer(null, cast(char*) bytes, 0, bytes.length, 0, 0,  errorSinkNull, &global.compileEnv);

		do
		{
			lexer.nextToken();
			tokens ~= lexer.token;
			tokenIndexes[lexer.token.loc.fileOffset] = cast(uint) tokens.length - 1;
		}
		while (lexer.token.value != TOK.endOfFile);
	}

	override void visit(AST.TemplateDeclaration templateDecl)
	{
		import std.algorithm : filter;
		import std.range : front, retro;

		super.visit(templateDecl);

		if (templateDecl.constraint is null || templateDecl.members is null)
			return;

		auto firstMember = (*(templateDecl.members))[0];
		uint templateLine = templateDecl.loc.linnum;
		uint templateCol = templateDecl.loc.charnum;

		auto templateTokenIdx = tokenIndexes[templateDecl.loc.fileOffset];
		if (tokens[templateTokenIdx].value != TOK.template_)
		{
			if (auto func = firstMember.isFuncDeclaration())
			{
				auto loc = computeFunctionTemplateLoc(func);
				templateLine = loc[0];
				templateCol = loc[1];
			}
			else
			{
				templateLine = firstMember.loc.linnum;
				templateCol = firstMember.loc.charnum;
			}
		}

		int constraintIdx = tokenIndexes[templateDecl.constraint.loc.fileOffset];
		auto constraintToken = tokens[0 .. constraintIdx].retro.filter!(t => t.value == TOK.if_).front;
		uint constraintLine = constraintToken.loc.linnum;
		uint constraintCol = constraintToken.loc.charnum;

		if (templateLine == constraintLine || templateCol != constraintCol)
			addErrorMessage(cast(ulong) constraintLine, cast(ulong) constraintCol, KEY, MSG);
	}

	private Tuple!(uint, uint) computeFunctionTemplateLoc(AST.FuncDeclaration func)
	{
		import std.algorithm : canFind;
		import std.conv : to;

		if (auto typeFunc = func.type.isTypeFunction())
		{
			if (auto type = typeFunc.next.isTypeInstance())
			{
				return tuple(type.loc.linnum, type.loc.charnum);
			}
			else if (to!string(typeFunc.next.kind()).canFind("array"))
			{
				auto idx = tokenIndexes[func.loc.fileOffset] - 1;
				while (tokens[idx].value == TOK.rightBracket)
				{
					while (tokens[idx].value != TOK.leftBracket)
						idx--;

					idx--;
				}

				auto token = tokens[idx];
				return tuple(token.loc.linnum, token.loc.charnum);
			}
		}

		auto idx = tokenIndexes[func.loc.fileOffset] - 1;
		auto token = tokens[idx];
		return tuple(token.loc.linnum, token.loc.charnum);
	}
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;
	import std.format : format;
	import std.stdio : stderr;

	StaticAnalysisConfig sac = disabledConfig();
	sac.if_constraints_indent = Check.enabled;
	enum MSG = "If constraints should have the same indentation as the function";

	assertAnalyzerWarningsDMD(q{
char[digestLength!(Hash)*2] hexDigest(Hash, Order order = Order.increasing, T...)(scope const T data)
if (allSatisfy!(isArray, typeof(data)))
{
    return toHexString!order(digest!Hash(data));
}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
ElementType!(A) pop (A) (ref A a)
if (isDynamicArray!(A) && !isNarrowString!(A) && isMutable!(A) && !is(A == void[]))
{
    auto e = a.back;
    a.popBack();
    return e;
}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
	template HMAC(H)
	if (isDigest!H && hasBlockSize!H)
	{
	    alias HMAC = HMAC!(H, H.blockSize);
	}
	}, sac);

	assertAnalyzerWarningsDMD(q{
void foo(R)(R r)
if (R == null)
{}

void foo(R)(R r)
	if (R == null) // [warn]: %s
{}
	}c.format(MSG), sac);

	assertAnalyzerWarningsDMD(q{
	void foo(R)(R r)
	if (R == null)
	{}

	void foo(R)(R r)
if (R == null) // [warn]: %s
	{}

	void foo(R)(R r)
		if (R == null) // [warn]: %s
	{}
	}c.format(MSG, MSG), sac);

	assertAnalyzerWarningsDMD(q{
	struct Foo(R)
	if (R == null)
	{}

	struct Foo(R)
if (R == null) // [warn]: %s
	{}

	struct Foo(R)
		if (R == null) // [warn]: %s
	{}
	}c.format(MSG, MSG), sac);

	// test example from Phobos
	assertAnalyzerWarningsDMD(q{
Num abs(Num)(Num x) @safe pure nothrow
if (is(typeof(Num.init >= 0)) && is(typeof(-Num.init)) &&
	!(is(Num* : const(ifloat*)) || is(Num* : const(idouble*))
	|| is(Num* : const(ireal*))))
{
	static if (isFloatingPoint!(Num))
		return fabs(x);
	else
		return x >= 0 ? x : -x;
}
	}, sac);

	// weird constraint formatting
	assertAnalyzerWarningsDMD(q{
	struct Foo(R)
	if
	(R == null)
	{}

	struct Foo(R)
	if
		(R == null)
	{}

	struct Foo(R)
if // [warn]: %s
	(R == null)
	{}

	struct Foo(R)
	if (
	R == null)
	{}

	struct Foo(R)
	if (
		R == null
	)
	{}

	struct Foo(R)
		if ( // [warn]: %s
		R == null
	) {}
	}c.format(MSG, MSG), sac);

	// constraint on the same line
	assertAnalyzerWarningsDMD(q{
	struct CRC(uint N, ulong P) if (N == 32 || N == 64) // [warn]: %s
	{}
	}c.format(MSG), sac);

	stderr.writeln("Unittest for IfConstraintsIndentCheck passed.");
}

@("issue #829")
unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;
	import std.stdio : stderr;

	StaticAnalysisConfig sac = disabledConfig();
	sac.if_constraints_indent = Check.enabled;

	assertAnalyzerWarningsDMD(`void foo() {
	''
}`, sac);
}
