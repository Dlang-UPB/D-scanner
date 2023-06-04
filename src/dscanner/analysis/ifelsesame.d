//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.ifelsesame;

import dscanner.analysis.base;

/**
 * Checks for duplicated code in conditional and logical expressions.
 * $(UL
 * $(LI If statements whose "then" block is the same as the "else" block)
 * $(LI || and && expressions where the left and right are the same)
 * $(LI == expressions where the left and right are the same)
 * )
 */
extern(C++) class IfElseSameCheck(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"if_else_same_check";

	extern(D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.IfStatement s)
	{
		import std.conv : to;

		if (s.elsebody && to!string(s.ifbody.toChars()) == to!string(s.elsebody.toChars()))
			addErrorMessage(cast(ulong) s.loc.linnum, cast(ulong) s.loc.charnum,
							IF_KEY, IF_MESSAGE);
	
		super.visit(s);
	}

	override void visit(AST.LogicalExp e)
	{
		import dmd.tokens : EXP;
		import std.conv : to;
		import std.string : format;
		import std.stdio : writeln;

		if (to!string(e.e1.toChars()) == to!string(e.e2.toChars()))
			addErrorMessage(cast(ulong) e.loc.linnum, cast(ulong) e.loc.charnum,
							LOGICAL_EXP_KEY, LOGICAL_EXP_MESSAGE.format(e.op == EXP.orOr ? "or" : "and"));

		super.visit(e);
	}

	private:
		enum IF_KEY = "dscanner.bugs.if_else_same";
		enum IF_MESSAGE = "'Else' branch is identical to 'Then' branch.";
		
		enum LOGICAL_EXP_MESSAGE = "MUIEEEELeft side of logical %s is identical to right side.";
		enum LOGICAL_EXP_KEY = "dscanner.bugs.logic_operator_operands";

		enum ASSIGN_MESSAGE = "Left side of assignment operatior is identical to the right side.";
		enum ASSIGN_KEY = "dscanner.bugs.self_assignment";
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarnings = assertAnalyzerWarningsDMD;
	import std.stdio : stderr;

	StaticAnalysisConfig sac = disabledConfig();
	sac.if_else_same_check = Check.enabled;
	assertAnalyzerWarnings(q{
		void testSizeT()
		{
			string person = "unknown";
			if (person == "unknown") // [warn]: 'Else' branch is identical to 'Then' branch.
				person = "bobrick"; // same
			else
				person = "bobrick"; // same

			if (person == "unknown") // ok
				person = "ricky"; // not same
			else
				person = "bobby"; // not same
		}
	}c, sac);

	assertAnalyzerWarnings(q{
		void foo()
		{
			if (auto stuff = call()) {}
		}
	}c, sac);

	stderr.writeln("Unittest for IfElseSameCheck passed.");
}
