module dscanner.analysis.mylexer;

import dmd.lexer;
import dmd.tokens;

class MyLexer : Lexer {
    alias nextToken = myNextToken;
    
    this(const(char)* filename, const(char)* base, size_t begoffset,
        size_t endoffset, bool doDocComment, bool commentToken) pure
        {
            super(filename, base, begoffset, endoffset, doDocComment, commentToken);
        }

    Token[] tokens;

    TOK myNextToken()
    {
        auto ret = super.nextToken();
        tokens ~= token;
        return ret;
    }
}