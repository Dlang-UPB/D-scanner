//          Copyright Basile Burg 2016.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.auto_function;

import dscanner.analysis.base;
import dscanner.analysis.helpers;

import std.stdio;

/**
 * Checks for auto functions without return statement.
 *
 * Auto function without return statement can be an omission and are not
 * detected by the compiler. However sometimes they can be used as a trick
 * to infer attributes.
 */
extern(C++) class AutoFunctionChecker(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"auto_function_check";

	///
	extern(D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.FuncDeclaration d)
	{
		import dmd.astenums : STC, STMT;

		if (d.storage_class & STC.disable)
			return;

		if (!(d.storage_class & STC.auto_) && !d.inferRetType)
		{
			super.visitFuncBody(d);
			return;
		}

		// arrow functions
		if (auto rs = d.fbody.isReturnStatement())
			return;

		// // fbody is either return or compound statement
		auto cs = d.fbody.isCompoundStatement();

		// look for asser(0) or assert(false)
		foreach (s; *cs.statements)
		{
			AST.ExpStatement es = s.isExpStatement();
			AST.AssertExp ae = null;

			if (es && es.exp)
				ae = es.exp.isAssertExp();

			if (ae)
			{
				auto ie = ae.e1.isIntegerExp();

				if (ie && ie.getInteger() == 0)
				{
					super.visitFuncBody(d);
					return;
				}
			}
		}

		foundReturnStatement = false;
		super.visitFuncBody(d);

		if (!foundReturnStatement)
			addErrorMessage(cast(ulong) d.loc.linnum, cast(ulong) d.loc.charnum, KEY, MESSAGE);
	}

	override void visit(AST.StaticForeachStatement s)
	{
		if (s.sfe.aggrfe)
			super.visit(s.sfe.aggrfe);

		if (s.sfe.rangefe)
			super.visit(s.sfe.rangefe);
	}

	override void visit(AST.ReturnStatement s)
	{
		foundReturnStatement = true;
	}

private:
	bool foundReturnStatement;
	enum string KEY = "dscanner.suspicious.missing_return";
	enum string MESSAGE = "Auto function without return statement, prefer an explicit void";
}

unittest
{
	import std.stdio : stderr;
	import std.format : format;
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarnings = assertAnalyzerWarningsDMD;

	StaticAnalysisConfig sac = disabledConfig();
	sac.auto_function_check = Check.enabled;
	
	assertAnalyzerWarnings(q{
		auto ref doStuff1(){} // [warn]: Auto function without return statement, prefer an explicit void
		auto doStuff2(){} // [warn]: Auto function without return statement, prefer an explicit void
		
		int doStuff3()
		{
			auto doStuff(){} // [warn]: Auto function without return statement, prefer an explicit void
			return 0;
		}
		
		auto doStuff4(){return 0;}
	}c, sac, true);

	assertAnalyzerWarnings(q{
		auto doStuff1(){assert(true);} // [warn]: Auto function without return statement, prefer an explicit void
		auto doStuff2(){assert(false);}
	}c, sac, true);

	assertAnalyzerWarnings(q{
		auto doStuff1(){assert(1);} // [warn]: Auto function without return statement, prefer an explicit void
		auto doStuff2(){assert(0);}
	}c, sac, true);

	assertAnalyzerWarnings(q{
		auto doStuff1() // [warn]: Auto function without return statement, prefer an explicit void
		{
			mixin("int a = 0 + 0;");
		}
		
		auto doStuff2(){mixin("return 0;");}
	}c, sac, true);

	assertAnalyzerWarnings(q{
		auto doStuff1() // [warn]: Auto function without return statement, prefer an explicit void
		{
			mixin("int a = 0;");
		}

		auto doStuff2(){mixin("static if (true)" ~ "  return " ~ 0.stringof ~ ";");}
	}c, sac, true);

	assertAnalyzerWarnings(q{
		auto doStuff1(){} // [warn]: Auto function without return statement, prefer an explicit void
		@disable auto doStuff2() {}
	}c, sac, true);

	assertAnalyzerWarnings(q{
		@property doStuff1(){} // [warn]: Auto function without return statement, prefer an explicit void
		@safe doStuff2(){} // [warn]: Auto function without return statement, prefer an explicit void
		@disable doStuff3() {}
		@safe void doStuff4();
	}c, sac, true);

	stderr.writeln("Unittest for AutoFunctionChecker passed.");
}
