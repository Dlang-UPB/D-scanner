//          Copyright Brian Schott (Hackerpilot) 2015.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.redundant_parens;

import dscanner.analysis.base;

/**
 * Checks for redundant parenthesis
 */
extern (C++) class RedundantParenCheck(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"redundant_parens_check";

	private enum string KEY = "dscanner.suspicious.redundant_parens";
	private enum string MESSAGE = "Redundant parenthesis.";

	extern (D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.IfStatement ifStatement)
	{
		import dscanner.utils : readFile;
		import dmd.errorsink : ErrorSinkNull;
		import dmd.globals : global;
		import dmd.lexer : Lexer;
		import dmd.tokens : TOK;

		__gshared ErrorSinkNull errorSinkNull;
		if (!errorSinkNull)
			errorSinkNull = new ErrorSinkNull;

		auto bytes = readFile(fileName) ~ '\0';
		bytes = bytes[ifStatement.loc.fileOffset .. $];

		scope lexer = new Lexer(null, cast(char*) bytes, 0, bytes.length, 0, 0, errorSinkNull, &global.compileEnv);
		while (lexer.token.value != TOK.leftParenthesis)
			lexer.nextToken();

		lexer.nextToken();
		if (lexer.token.value != TOK.leftParenthesis)
			return;

		int openParensCount = 2;
		while (openParensCount > 1)
		{
			lexer.nextToken();

			switch (lexer.token.value)
			{
			case TOK.rightParenthesis:
				openParensCount--;
				break;
			case TOK.leftParenthesis:
				openParensCount++;
				break;
			default:
				break;
			}
		}

		lexer.nextToken();
		if (lexer.token.value == TOK.rightParenthesis)
			addErrorMessage(cast(ulong) ifStatement.loc.linnum, cast(ulong) ifStatement.loc.charnum, KEY, MESSAGE);
	}
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;
	import std.stdio : stderr;

	StaticAnalysisConfig sac = disabledConfig();
	sac.redundant_parens_check = Check.enabled;

	assertAnalyzerWarningsDMD(q{
		void testRedundantParens()
		{
			int a = 0;
			bool b = true;

			if ((a + 2 == 3)) // [warn]: Redundant parenthesis.
			{

			}

			if ((b)) // [warn]: Redundant parenthesis.
			{

			}

			if (b) { }

			if (a * 2 == 0) { }

			if ((a + 2) == (3 + 5)) { }
		}
	}c, sac);

	stderr.writeln("Unittest for RedundantParenthesis passed.");

}
