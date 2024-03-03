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
import std.typecons : Tuple, tuple;

/**
 * Checks for duplicated code in conditional and logical expressions.
 * $(UL
 * $(LI If statements whose "then" block is the same as the "else" block)
 * $(LI || and && expressions where the left and right are the same)
 * $(LI == and != expressions where the left and right are the same)
 * $(LI >, <, >=, and <= expressions where the left and right are the same)
 * $(LI Assignments where the left and right are the same)
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
	private enum ASSIGN_MESSAGE = "Left side of assignment operation is identical to the right side.";

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

	mixin VisitBinaryExpression!(AST.LogicalExp);
	//mixin VisitBinaryExpression!(AST.EqualExp);
	//mixin VisitBinaryExpression!(AST.CmpExp);
	//mixin VisitBinaryExpression!(AST.AssignExp);

	private template VisitBinaryExpression(NodeType)
	{
		override void visit(NodeType node)
		{
			super.visit(node);

			auto expr1 = to!string(toChars(node.e1));
			auto expr2 = to!string(toChars(node.e2));

			if (expr1 == expr2)
			{
				auto lineNum = cast(ulong) node.loc.linnum;
				auto charNum = cast(ulong) node.loc.charnum;
				auto errorInfo = getErrorInfo(node.op);
				addErrorMessage(lineNum, charNum, errorInfo[0], errorInfo[1]);
			}
		}
	}

	private extern (D) Tuple!(string, string) getErrorInfo(EXP op)
	{
		switch (op)
		{
		case EXP.orOr:
			return tuple(LOGICAL_EXP_KEY, LOGICAL_EXP_MESSAGE.format("or"));
		case EXP.andAnd:
			return tuple(LOGICAL_EXP_KEY, LOGICAL_EXP_MESSAGE.format("and"));
		case EXP.equal:
			return tuple(CMP_KEY, CMP_MESSAGE.format("'=='"));
		case EXP.notEqual:
			return tuple(CMP_KEY, CMP_MESSAGE.format("'!='"));
		case EXP.lessThan:
			return tuple(CMP_KEY, CMP_MESSAGE.format("'<'"));
		case EXP.lessOrEqual:
			return tuple(CMP_KEY, CMP_MESSAGE.format("'<='"));
		case EXP.greaterThan:
			return tuple(CMP_KEY, CMP_MESSAGE.format("'>'"));
		case EXP.greaterOrEqual:
			return tuple(CMP_KEY, CMP_MESSAGE.format("'>='"));
		case EXP.assign:
			return tuple(ASSIGN_KEY, ASSIGN_MESSAGE);
		default:
			assert(0);
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

	//assertAnalyzerWarningsDMD(q{
	//	void testCmpExprSame()
	//	{
	//		int a = 1, b = 2;
	//
	//		if (a == b) {}
	//		if (a == a) {} // [warn]: Left side of '==' operator is identical to right side.
	//
	//		if (a != b) {}
	//		if (a != a) {} // [warn]: Left side of '!=' operator is identical to right side.
	//
	//		b = a == a ? 1 : 2; // [warn]: Left side of '==' operator is identical to right side.
	//
	//		if (a > b) {}
	//		if (a > a) {} // [warn]: Left side of '>' operator is identical to right side.
	//
	//		if (a < b) {}
	//		if (a < a) {} // [warn]: Left side of '<' operator is identical to right side.
	//
	//		if (a >= b) {}
	//		if (a >= a) {} // [warn]: Left side of '>=' operator is identical to right side.
	//
	//		if (a <= b) {}
	//		if (a <= a) {} // [warn]: Left side of '<=' operator is identical to right side.
	//	}
	//}c, sac);

	//assertAnalyzerWarningsDMD(q{
	//	void testAssignSame()
	//	{
	//		int a = 1;
	//		a = 5;
	//		a = a; // [warn]: Left side of assignment operation is identical to the right side.
	//	}
	//}c, sac);

	assertAnalyzerWarningsDMD(q{
		void foo()
		{
			if (auto stuff = call()) {}
		}
	}c, sac);

	stderr.writeln("Unittest for IfElseSameCheck passed.");
}
