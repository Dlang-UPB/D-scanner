//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.numbers;

import dscanner.analysis.base;
import dmd.tokens : TOK;
import std.conv;
import std.regex;
import std.stdio;

/**
 * Checks for long and hard-to-read number literals
 */
extern (C++) class NumberStyleCheck(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"number_style_check";

	private enum KEY = "dscanner.style.number_literals";
	private enum string MSG = "Use underscores to improve number constant readability.";

	private auto badBinaryRegex = ctRegex!(`^0b[01]{9,}`);
	private auto badDecimalRegex = ctRegex!(`^\d{5,}`);

	extern (D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.IntegerExp intExpr)
	{
		import dscanner.utils : readFile;
		import dmd.errorsink : ErrorSinkNull;
		import dmd.globals : global;
		import dmd.lexer : Lexer;

		auto bytes = readFile(fileName) ~ '\0';
		bytes = bytes[intExpr.loc.fileOffset .. $];

		__gshared ErrorSinkNull errorSinkNull;
		if (!errorSinkNull)
			errorSinkNull = new ErrorSinkNull;

		scope lexer = new Lexer(null, cast(char*) bytes, 0, bytes.length, 0, 0, errorSinkNull, &global.compileEnv);
		lexer.nextToken();

		auto tokenValue = lexer.token.value;
		auto tokenText = to!string(lexer.token.ptr);

		if (!isIntegerLiteral(tokenValue))
			return;

		if (!matchFirst(tokenText, badDecimalRegex).empty || !matchFirst(tokenText, badBinaryRegex).empty)
			addErrorMessage(intExpr.loc.linnum, intExpr.loc.charnum, KEY, MSG);
	}

	private bool isIntegerLiteral(TOK token)
	{
		return token >= TOK.int32Literal && token <= TOK.uns128Literal;
	}
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;

	StaticAnalysisConfig sac = disabledConfig();
	sac.number_style_check = Check.enabled;
	assertAnalyzerWarningsDMD(q{
		void testNumbers()
		{
			int a;
			a = 1; // ok
			a = 10; // ok
			a = 100; // ok
			a = 1000; // ok
			a = 10000; // [warn]: Use underscores to improve number constant readability.
			a = 100000; // [warn]: Use underscores to improve number constant readability.
			a = 1000000; // [warn]: Use underscores to improve number constant readability.
		}
	}c, sac);

	stderr.writeln("Unittest for NumberStyleCheck passed.");
}
