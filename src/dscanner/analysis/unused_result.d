//          Copyright Vladimir Panteleev 2020
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)
module dscanner.analysis.unused_result;

import dscanner.analysis.base;

/**
 * Checks for function call statements which call non-void functions.
 *
 * In case the function returns a value indicating success/failure,
 * ignoring this return value and continuing execution can lead to
 * undesired results.
 *
 * When the return value is intentionally discarded, `cast(void)` can
 * be prepended to silence the check.
 */
extern(C++) class UnusedResultChecker(AST) : BaseAnalyzerDmd
{
    alias visit = BaseAnalyzerDmd.visit;
    mixin AnalyzerInfo!"unused_result";

    extern(D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

    mixin VisitInstructionBlock!(AST.WhileStatement);
	mixin VisitInstructionBlock!(AST.ForStatement);
	mixin VisitInstructionBlock!(AST.DoStatement);
	mixin VisitInstructionBlock!(AST.ForeachRangeStatement);
	mixin VisitInstructionBlock!(AST.ForeachStatement);
	mixin VisitInstructionBlock!(AST.SwitchStatement);
	mixin VisitInstructionBlock!(AST.SynchronizedStatement);
	mixin VisitInstructionBlock!(AST.WithStatement);
	mixin VisitInstructionBlock!(AST.TryCatchStatement);
	mixin VisitInstructionBlock!(AST.TryFinallyStatement);
    
    override void visit(AST.CompoundStatement s)
	{
		foreach (st; *s.statements)
		{
			if (checkStatement(st))
				addErrorMessage(cast(ulong) st.loc.linnum,
						cast(ulong) st.loc.charnum, KEY, MSG);

			st.accept(this);
		}
	}

	override void visit(AST.IfStatement s)
	{
		if (checkStatement(s.ifbody))
					addErrorMessage(cast(ulong) s.ifbody.loc.linnum,
						cast(ulong) s.ifbody.loc.charnum, KEY, MSG);

		if (s.elsebody && checkStatement(s.elsebody))
					addErrorMessage(cast(ulong) s.elsebody.loc.linnum,
						cast(ulong) s.elsebody.loc.charnum, KEY, MSG);
		
		super.visit(s);
	}

	bool checkStatement(AST.Statement s)
	{
		import dmd.astenums : TY;

        if (auto es = s.isExpStatement()) if (auto ce = es.exp.isCallExp())
		{
            if (!ce.f)
                return false;

			auto tf = ce.f.type.isTypeFunction();

			if (!tf)
				return false;

			if (tf.next.ty != TY.Tvoid)
				return true;
		}

		return false;
	}

	private:
		template VisitInstructionBlock(T)
		{
			override void visit(T t)
			{
				if (checkStatement(t._body))
					addErrorMessage(cast(ulong) t._body.loc.linnum,
						cast(ulong) t._body.loc.charnum, KEY, MSG);

				super.visit(t);
			}
		}

	enum KEY = "dscanner.performance.enum_array_literal";
	enum string MSG = "Function return value is discarded";
}

unittest
{
    import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
    import dscanner.analysis.helpers : assertAnalyzerWarnings = assertAnalyzerWarningsDMD;
    import std.stdio : stderr;
    import std.format : format;

    enum string MSG = "Function return value is discarded";
    StaticAnalysisConfig sac = disabledConfig();
    sac.unused_result = Check.enabled;

    assertAnalyzerWarnings(q{
        void fun() {}
        void main()
        {
            fun();
        }
    }c, sac, 1);

    assertAnalyzerWarnings(q{
        int fun() { return 1; }
        void main()
        {
            fun(); // [warn]: %s
        }
    }c.format(MSG), sac, 1);

    assertAnalyzerWarnings(q{
        void main()
        {
            void fun() {}
            fun();
        }
    }c, sac, 1);

    // version (none) // TODO: local functions
    assertAnalyzerWarnings(q{
        void main()
        {
            int fun() { return 1; }
            fun(); // [warn]: %s
        }
    }c.format(MSG), sac, 1);

    assertAnalyzerWarnings(q{
        int fun() { return 1; }
        void main()
        {
            cast(void) fun();
        }
    }c, sac, 1);

    assertAnalyzerWarnings(q{
        void fun() { }
        alias gun = fun;
        void main()
        {
            gun();
        }
    }c, sac, 1);

    import std.stdio: writeln;
    writeln("Unittest for UnusedResultChecker passed");
}

