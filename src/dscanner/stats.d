//          Copyright Brian Schott (Hackerpilot) 2012.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.stats;

import std.stdio;
import std.algorithm;
import dparse.lexer;
import dmd.lexer : Lexer;
import dmd.tokens : TOK;

pure nothrow bool isLineOfCode(IdType t)
{
	switch (t)
	{
	case tok!";":
	case tok!"while":
	case tok!"if":
	case tok!"do":
	case tok!"else":
	case tok!"switch":
	case tok!"for":
	case tok!"foreach":
	case tok!"foreach_reverse":
	case tok!"default":
	case tok!"case":
		return true;
	default:
		return false;
	}
}

pure nothrow bool __isLineOfCode(TOK t)
{
	switch (t)
	{
	case TOK.semicolon:
	case TOK.do_:
	case TOK.while_:
	case TOK.if_:
	case TOK.else_:
	case TOK.for_:
	case TOK.foreach_:
	case TOK.foreach_reverse_:
	case TOK.switch_:
	case TOK.case_:
	case TOK.default_:
		return true;
	default:
		return false;
	}
}

ulong printTokenCount(File output, string fileName, ref Lexer lexer)
{
	TOK lastTOK = TOK.reserved;
	ulong c;
	foreach (ref t; lexer)
	{
		if (lastTOK == TOK.whitespace && t == TOK.whitespace)
			continue;
		++c;
		lastTOK = t;
	}
	output.writefln("%s:\t%d", fileName, c);
	return c;
}

ulong printLineCount(File output, string fileName, ref Lexer lexer)
{
	ulong c;
	foreach (ref t; lexer)
	{
		if (__isLineOfCode(t))
			++c;
	}
	output.writefln("%s:\t%d", fileName, c);
	return c;
}

unittest
{
	enum string[] tests = [
		";\n",

		"import std.stdio;\n"
		~ "void main()\n"
		~ "{\n"
		~ "\twriteln(\"Hello, world!\");\n"
		~ "}",

		"import std.stdio;\n"
		~ "\n"
		~ "void main(string[] args)\n"
		~ "{\n"
		~ "    char[] chars = \"abcd\".dup;\n"
		~ "\n"
		~ "// writeln(chars.sizeof);\n"
		~ "}",

		"if (a is null) {\n"
		~ "\treturn 1;\n"
		~ "} else {\n"
		~ "\twhile (b > 0) {\n"
		~ "\t\tb--;\n"
		~ "\t}\n"
		~ "}",
	];

	enum uint[string] tokenCountExpected = [
		tests[0] : 2,
		tests[1] : 22,
		tests[2] : 36,
		tests[3] : 42,
	];

	enum uint[string] lineCountExpected = [
		tests[0] : 1,
		tests[1] : 2,
		tests[2] : 2,
		tests[3] : 5,
	];

	foreach (string code; tests)
	{
		import std.stdio : File;
		import std.file : exists, remove;

		auto deleteme = "test.txt";
		File file = File(deleteme, "w");
		scope(exit)
		{
			assert(exists(deleteme));
			remove(deleteme);
		}

		Lexer tokenLexer = new Lexer(null, cast(char*) code.ptr, 0, code.length, false, true, true);
		tokenLexer.nextToken;

		ulong tokenCount = printTokenCount(file, deleteme, tokenLexer);
		assert(tokenCount == tokenCountExpected[code]);

		Lexer lineLexer = new Lexer(null, cast(char*) code.ptr, 0, code.length, false, true, true);
		lineLexer.nextToken;

		ulong lineCount = printLineCount(file, deleteme, lineLexer);
		assert(lineCount == lineCountExpected[code]);

		file.close();
	}
}
