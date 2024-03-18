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
extern (C++) class UnusedResultChecker(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"unused_result";
	private enum KEY = "dscanner.performance.enum_array_literal";
	private enum string MSG = "Function return value is discarded";

	extern (D) this(string fileName, bool skipTests = false)
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

	override void visit(AST.CompoundStatement compoundStatement)
	{
		foreach (statement; *compoundStatement.statements)
		{
			if (hasUnusedResult(statement))
			{
				auto lineNum = cast(ulong) statement.loc.linnum;
				auto charNum = cast(ulong) statement.loc.charnum;
				addErrorMessage(lineNum, charNum, KEY, MSG);
			}

			statement.accept(this);
		}
	}

	override void visit(AST.IfStatement ifStatement)
	{
		if (hasUnusedResult(ifStatement.ifbody))
		{
			auto lineNum = cast(ulong) ifStatement.ifbody.loc.linnum;
			auto charNum = cast(ulong) ifStatement.ifbody.loc.charnum;
			addErrorMessage(lineNum, charNum, KEY, MSG);
		}

		if (ifStatement.elsebody && hasUnusedResult(ifStatement.elsebody))
		{
			auto lineNum = cast(ulong) ifStatement.elsebody.loc.linnum;
			auto charNum = cast(ulong) ifStatement.elsebody.loc.charnum;
			addErrorMessage(lineNum, charNum, KEY, MSG);
		}

		super.visit(ifStatement);
	}

	private bool hasUnusedResult(AST.Statement statement)
	{
		import dmd.astenums : TY;

		auto exprStatement = statement.isExpStatement();
		if (exprStatement is null)
			return false;

		auto callExpr = exprStatement.exp.isCallExp();
		if (callExpr is null || callExpr.f is null)
			return false;

		auto typeFunction = callExpr.f.type.isTypeFunction();
		if (typeFunction is null)
			return false;

		TY type = typeFunction.next.ty;
		return type != TY.Tvoid && type != TY.Tnoreturn;
	}

	private template VisitInstructionBlock(T)
	{
		override void visit(T statement)
		{
			if (hasUnusedResult(statement._body))
			{
				auto lineNum = cast(ulong) statement._body.loc.linnum;
				auto charNum = cast(ulong) statement._body.loc.charnum;
				addErrorMessage(lineNum, charNum, KEY, MSG);
			}

			super.visit(statement);
		}
	}
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;
	import std.stdio : stderr;
	import std.format : format;

	enum string MSG = "Function return value is discarded";
	StaticAnalysisConfig sac = disabledConfig();
	sac.unused_result = Check.enabled;

	assertAnalyzerWarningsDMD(q{
		void fun() {}
        void main()
        {
            fun();
        }
    }c, sac, true);

	assertAnalyzerWarningsDMD(q{
        alias noreturn = typeof(*null);
        noreturn fun() { while (1) {} }
        noreturn main()
        {
            fun();
        }
    }c, sac, true);

	assertAnalyzerWarningsDMD(q{
        int fun() { return 1; }
        void main()
        {
            fun(); // [warn]: %s
        }
    }c.format(MSG), sac, true);

	assertAnalyzerWarningsDMD(q{
        struct Foo
        {
            static bool get()
            {
                return false;
            }
        }
        alias Bar = Foo;
        void main()
        {
            Bar.get(); // [warn]: %s
        }
    }c.format(MSG), sac, true);

	assertAnalyzerWarningsDMD(q{
        void main()
        {
            void fun() {}
            fun();
        }
    }c, sac, true);

	assertAnalyzerWarningsDMD(q{
        void main()
        {
            int fun() { return 1; }
            fun(); // [warn]: %s
        }
    }c.format(MSG), sac, true);

	assertAnalyzerWarningsDMD(q{
        int fun() { return 1; }
        void main()
        {
            cast(void) fun();
        }
    }c, sac, true);

	assertAnalyzerWarningsDMD(q{
        void fun() { }
        alias gun = fun;
        void main()
        {
            gun();
        }
    }c, sac, true);

	assertAnalyzerWarningsDMD(q{
        int fun() { return 1; }
        void main()
        {
        	if (true)
            	fun(); // [warn]: %s
            else
            	fun(); // [warn]: %s
        }
    }c.format(MSG, MSG), sac, true);

	assertAnalyzerWarningsDMD(q{
        int fun() { return 1; }
        void main()
        {
        	while (true)
            	fun(); // [warn]: %s
        }
    }c.format(MSG), sac, true);

	assertAnalyzerWarningsDMD(q{
        int fun() { return 1; }
        alias gun = fun;
        void main()
        {
            gun(); // [warn]: %s
        }
    }c.format(MSG), sac, true);

	assertAnalyzerWarningsDMD(q{
        void main()
        {
            void fun() {}
            fun();
        }
    }c, sac, true);

	stderr.writeln("Unittest for UnusedResultChecker passed");
}
