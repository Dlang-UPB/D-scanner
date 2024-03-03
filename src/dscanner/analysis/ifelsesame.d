//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.ifelsesame;

import dscanner.analysis.base;
import dmd.hdrgen : toChars;
import dmd.tokens : EXP;
import std.conv : to;
import std.string : format;

/**
 * Checks for duplicated code in conditional and logical expressions.
 * $(UL
 * $(LI If statements whose "then" block is the same as the "else" block)
 * $(LI || and && expressions where the left and right are the same)
 * $(LI == and != expressions where the left and right are the same)
 * $(LI >, <, >=, and <= expressions where the left and right are the same)
 * )
 */
extern (C++) class IfElseSameCheck(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"if_else_same_check";

	private enum IF_KEY = "dscanner.bugs.if_else_same";
	private enum IF_MESSAGE = "'Else' branch is identical to 'Then' branch.";

	private enum LOGICAL_EXP_KEY = "dscanner.bugs.logic_operator_operands";
	private enum LOGICAL_EXP_MESSAGE = "Left side of logical %s is identical to right side.";

	private enum CMP_KEY = "dscanner.bugs.comparison_operator_operands";
	private enum CMP_MESSAGE = "Left side of %s operator is identical to right side.";

	private enum ASSIGN_KEY = "dscanner.bugs.self_assignment";
	private enum ASSIGN_MESSAGE = "Left side of assignment operatior is identical to the right side.";

	extern (D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.IfStatement ifStatement)
	{
		super.visit(ifStatement);

		if (ifStatement.ifbody is null || ifStatement.elsebody is null)
			return;

		auto thenBody = to!string(toChars(ifStatement.ifbody));
		auto elseBody = to!string(toChars(ifStatement.elsebody));

		if (thenBody == elseBody)
		{
			auto lineNum = cast(ulong) ifStatement.loc.linnum;
			auto charNum = cast(ulong) ifStatement.loc.charnum;
			addErrorMessage(lineNum, charNum, IF_KEY, IF_MESSAGE);
		}
	}

	override void visit(AST.LogicalExp logicalExpr)
	{
		super.visit(logicalExpr);

		auto expr1 = to!string(toChars(logicalExpr.e1));
		auto expr2 = to!string(toChars(logicalExpr.e2));

		if (expr1 == expr2)
		{
			auto lineNum = cast(ulong) logicalExpr.loc.linnum;
			auto charNum = cast(ulong) logicalExpr.loc.charnum;
			auto errorMsg = LOGICAL_EXP_MESSAGE.format(exprOpToString(logicalExpr.op));
			addErrorMessage(lineNum, charNum, LOGICAL_EXP_KEY, errorMsg);
		}
	}

	override void visit(AST.EqualExp equalExp)
	{
		super.visit(equalExp);

		auto expr1 = to!string(toChars(equalExp.e1));
		auto expr2 = to!string(toChars(equalExp.e2));

		if (expr1 == expr2)
		{
			auto lineNum = cast(ulong) equalExp.loc.linnum;
			auto charNum = cast(ulong) equalExp.loc.charnum;
			auto errorMsg = CMP_MESSAGE.format(exprOpToString(equalExp.op));
			addErrorMessage(lineNum, charNum, CMP_KEY, errorMsg);
		}
	}

	override void visit(AST.CmpExp cmpExp)
	{
		super.visit(cmpExp);

		auto expr1 = to!string(toChars(cmpExp.e1));
		auto expr2 = to!string(toChars(cmpExp.e2));

		if (expr1 == expr2)
		{
			auto lineNum = cast(ulong) cmpExp.loc.linnum;
			auto charNum = cast(ulong) cmpExp.loc.charnum;
			auto errorMsg = CMP_MESSAGE.format(exprOpToString(cmpExp.op));
			addErrorMessage(lineNum, charNum, CMP_KEY, errorMsg);
		}
	}

	override void visit(AST.AssignExp assignExp)
	{
		super.visit(assignExp);

		auto expr1 = to!string(toChars(assignExp.e1));
		auto expr2 = to!string(toChars(assignExp.e2));

		if (expr1 == expr2)
		{
			auto lineNum = cast(ulong) assignExp.loc.linnum;
			auto charNum = cast(ulong) assignExp.loc.charnum;
			addErrorMessage(lineNum, charNum, ASSIGN_KEY, ASSIGN_MESSAGE);
		}
	}

	private extern (D) string exprOpToString(EXP op)
	{
		switch (op)
		{
		case EXP.orOr:
			return "or";
		case EXP.andAnd:
			return "and";
		case EXP.equal:
			return "'=='";
		case EXP.notEqual:
			return "'!='";
		case EXP.lessThan:
			return "'<'";
		case EXP.lessOrEqual:
			return "'<='";
		case EXP.greaterThan:
			return "'>'";
		case EXP.greaterOrEqual:
			return "'>='";
		default:
			return "unknown";
		}
	}
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;
	import std.stdio : stderr;

	StaticAnalysisConfig sac = disabledConfig();
	sac.if_else_same_check = Check.enabled;

	assertAnalyzerWarningsDMD(q{
		void testThenElseSame()
		{
			string person = "unknown";
			if (person == "unknown") // [warn]: 'Else' branch is identical to 'Then' branch.
				person = "bobrick";
			else
				person = "bobrick";

			if (person == "unknown")
				person = "ricky";
			else
				person = "bobby";
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		void testLogicalExprSame()
		{
			int a = 1, b = 2;

			if (a == 1 && b == 1) {}
			if (a == 1 && a == 1) {} // [warn]: Left side of logical and is identical to right side.

			if (a == 1 || b == 1) {}
			if (a == 1 || a == 1) {} // [warn]: Left side of logical or is identical to right side.
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		void testCmpExprSame()
		{
			int a = 1, b = 2;

			if (a == b) {}
			if (a == a) {} // [warn]: Left side of '==' operator is identical to right side.

			if (a != b) {}
			if (a != a) {} // [warn]: Left side of '!=' operator is identical to right side.

			b = a == a ? 1 : 2; // [warn]: Left side of '==' operator is identical to right side.

			if (a > b) {}
			if (a > a) {} // [warn]: Left side of '>' operator is identical to right side.

			if (a < b) {}
			if (a < a) {} // [warn]: Left side of '<' operator is identical to right side.

			if (a >= b) {}
			if (a >= a) {} // [warn]: Left side of '>=' operator is identical to right side.

			if (a <= b) {}
			if (a <= a) {} // [warn]: Left side of '<=' operator is identical to right side.
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		void testAssignSame()
		{
			int a = 1;
			a = 5;
			a = a; // [warn]: Left side of assignment operatior is identical to the right side.
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		void foo()
		{
			if (auto stuff = call()) {}
		}
	}c, sac);

	stderr.writeln("Unittest for IfElseSameCheck passed.");
}
