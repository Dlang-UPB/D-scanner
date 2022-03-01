//          Copyright Brian Schott (Hackerpilot) 2012.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.stats;

import std.stdio;
import std.algorithm;
import dparse.lexer;

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

ulong printTokenCount(Tokens)(File output, string fileName, ref Tokens tokens)
{
	ulong c;
	foreach (ref t; tokens)
	{
		c++;
	}
	output.writefln("%s:\t%d", fileName, c);
	return c;
}

ulong printLineCount(Tokens)(File output, string fileName, ref Tokens tokens)
{
	ulong count;
	foreach (ref t; tokens)
	{
		if (isLineOfCode(t.type))
			++count;
	}
	output.writefln("%s:\t%d", fileName, count);
	return count;
}

void printTokenDump(string fileName)
{
	import dmd.tokens;
	import dmd.lexer;
	import std.file;

	auto input = readText(fileName);
	scope lexer = new Lexer(null, input.ptr, 0, input.length, 0, 0);
    
	lexer.nextToken;
	Token t = lexer.token;

	writeln("text                    \tblank\tindex\tline\tcolumn\ttype\tcomment\ttrailingComment");
	do
    {
		import std.stdio : writefln;
		t = lexer.token;
		string aux;
		bool empty = true;

		switch (t.value)
		{
			case TOK.string_:
				aux = t.ustring[0 .. t.len].dup;
				aux = "\"" ~ aux ~ "\"";
				writef("<<%20s>>", aux);
				empty = false;
				break;
			case TOK.int32Literal:
				writef("<<%20d>>", t.intvalue);
				empty = false;
				break;
			case TOK.int64Literal:
				writef("<<%20lldL>>", cast(long)t.intvalue);
				empty = false;
				break;
			case TOK.uns32Literal:
				writef("<<%20uU>>", t.unsvalue);
				empty = false;
				break;
			case TOK.uns64Literal:
				writef("<<%20lluUL>>", t.unsvalue);
				empty = false;
				break;
			case TOK.float32Literal:
			case TOK.float64Literal:
			case TOK.float80Literal:
				writef("<<%20g>>", t.floatvalue);
				empty = false;
				break;
			case TOK.identifier:
				writef("<<%20s>>", t.ident.toString());
				empty = false;
				break;
			case TOK.wcharLiteral:
			case TOK.dcharLiteral:
			case TOK.charLiteral:
				aux = "\'" ~ cast(char) t.unsvalue ~ "\'";
				writef("<<%20s>>", aux);
				empty = false;
				break;
			default:
				writef("<<%20s>>", Token.toString(t.value));
				break;
		}

		writefln("\t%b\t%d\t%d\t%d\t%d\t%s\t%s",
					empty,
					t.loc.fileOffset,
					t.loc.linnum,
					t.loc.charnum,
					t.value,
					t.blockComment,
					t.lineComment);
    } while (lexer.nextToken != TOK.endOfFile);
}

unittest
{
	import std.file;                                                                                                                                                                                                                                                                          
	import core.stdc.stdio : freopen, stdout;                                                                                                                                                                                                                                                 
	import core.sys.posix.unistd : dup, dup2;
	import std.stdio : File;
	import std.file : exists, remove;

	auto deleteme = "test.txt";
	File file = File(deleteme, "w");

	file.write(
q{import std.stdio;
void main(string[] args)
{
	writeln("Hello World");
	// this is a comment
	char c = 'd';
	float x = 1.23;
}});

	file.close();

	auto deleteme2 = "test2.txt";
	auto fp = freopen("test2.txt", "w", stdout);

	printTokenDump(deleteme);
	fflush(fp);
	fclose(fp);

	auto actual = readText(deleteme2);
	auto expected = "text                    	blank	index	line	column	type	comment	trailingComment
<<              import>>	1	0	1	1	131		
<<                 std>>	0	7	1	8	96		
<<                   .>>	1	10	1	11	76		
<<               stdio>>	0	11	1	12	96		
<<                   ;>>	1	16	1	17	9		
<<                void>>	1	18	2	1	102		
<<                main>>	0	23	2	6	96		
<<                   (>>	1	27	2	10	1		
<<              string>>	0	28	2	11	96		
<<                   [>>	1	34	2	17	3		
<<                   ]>>	1	35	2	18	4		
<<                args>>	0	37	2	20	96		
<<                   )>>	1	41	2	24	2		
<<                   {>>	1	43	3	1	5		
<<             writeln>>	0	46	4	2	96		
<<                   (>>	1	53	4	9	1		
<<       \"Hello World\">>	0	54	4	10	97		
<<                   )>>	1	67	4	23	2		
<<                   ;>>	1	68	4	24	9		
<<                char>>	1	93	6	2	122		
<<                   c>>	0	98	6	7	96		
<<                   =>>	1	100	6	9	71		
<<                 'd'>>	0	102	6	11	93		
<<                   ;>>	1	105	6	14	9		
<<               float>>	1	108	7	2	113		
<<                   x>>	0	114	7	8	96		
<<                   =>>	1	116	7	10	71		
<<                1.23>>	0	118	7	12	88		
<<                   ;>>	1	122	7	16	9		
<<                   }>>	1	124	8	1	6		
";

	scope(exit)
	{
		assert(exists(deleteme));
        remove(deleteme);
		assert(exists(deleteme2));
		remove(deleteme2);
	}

	assert(actual == expected);
}