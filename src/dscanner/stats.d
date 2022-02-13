//          Copyright Brian Schott (Hackerpilot) 2012.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.stats;

import std.stdio;
import std.algorithm;
import dparse.lexer;
import dmd.tokens;

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

// ulong printTokenCount(Tokens)(File output, string fileName, ref Tokens tokens)
ulong printTokenCount(File output, string fileName, ref TOK[] tokens)
{
	bool foundWhitespace = false;
	ulong c;
	foreach (ref t; tokens)
	{
		if (!foundWhitespace && t == TOK.whitespace)
			foundWhitespace = true;
		else if (t != TOK.whitespace)
			foundWhitespace = false;
		else if (foundWhitespace && t == TOK.whitespace)
			continue;
		c++;

		stdout.writeln(dmd.tokens.Token.toString(t));
	}
	output.writefln("%s:\t%d", fileName, c);
	return c;
}

// ulong printLineCount(Tokens)(File output, string fileName, ref Tokens tokens)
ulong printLineCount(File output, string fileName, ref TOK[] tokens)
{
	ulong c;
	foreach (ref t; tokens)
	{
		if (__isLineOfCode(t))
			++c;
	}
	output.writefln("%s:\t%d", fileName, c);
	return c;
}
