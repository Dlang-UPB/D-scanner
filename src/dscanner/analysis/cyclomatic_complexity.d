// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.cyclomatic_complexity;

import dscanner.analysis.base;
import dmd.location : Loc;
import std.format;

/// Implements a basic cyclomatic complexity algorithm using the AST.
///
/// Issues a warning on functions whenever the cyclomatic complexity of them
/// passed over a configurable threshold.
///
/// The complexity score starts at 1 and is increased each time on
/// - `if`
/// - switch `case`
/// - any loop
/// - `&&`
/// - `||`
/// - `?:` (ternary operator)
/// - `throw`
/// - `catch`
/// - `return`
/// - `break` (unless in case)
/// - `continue`
/// - `goto`
/// - function literals
///
/// See: https://en.wikipedia.org/wiki/Cyclomatic_complexity
/// Rules based on http://cyvis.sourceforge.net/cyclomatic_complexity.html
/// and https://github.com/fzipp/gocyclo
extern (C++) class CyclomaticComplexityCheck(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"cyclomatic_complexity";

	/// Maximum cyclomatic complexity. Once the cyclomatic complexity is greater
	/// than this threshold, a warning is issued.
	///
	/// By default 50 is used as threshold, which is considered almost
	/// unmaintainable / untestable.
	///
	/// For clean development a threshold like 20 can be used instead.
	immutable int maxCyclomaticComplexity;

	private enum string KEY = "dscanner.metric.cyclomatic_complexity";
	private enum string MESSAGE = "Cyclomatic complexity of this function is %s.";

	private int[] complexityStack = [0];
	private bool[] inLoop = [false];

	extern (D) this(string fileName, bool skipTests = false, int maxCyclomaticComplexity = 50)
	{
		super(fileName, skipTests);
		this.maxCyclomaticComplexity = maxCyclomaticComplexity;
	}

	override void visit(AST.TemplateDeclaration templateDecl)
	{
		foreach (member; *templateDecl.members)
			member.accept(this);
	}

	override void visit(AST.FuncDeclaration funDecl)
	{
		if (funDecl.fbody is null)
			return;

		analyzeFunctionBody(funDecl.fbody, funDecl.loc);
	}

	override void visit(AST.UnitTestDeclaration unitTestDecl)
	{
		if (skipTests)
			return;

		analyzeFunctionBody(unitTestDecl.fbody, unitTestDecl.loc);
	}

	private void analyzeFunctionBody(AST.Statement functionBody, Loc location)
	{
		complexityStack.assumeSafeAppend ~= 1;
		inLoop.assumeSafeAppend ~= false;
		scope (exit)
		{
			complexityStack.length--;
			inLoop.length--;
		}

		functionBody.accept(this);
		testComplexity(location.linnum, location.charnum);
	}

	private void testComplexity(size_t line, size_t column)
	{
		auto complexity = complexityStack[$ - 1];
		if (complexity > maxCyclomaticComplexity)
			addErrorMessage(line, column, KEY, format!MESSAGE(complexity));
	}

	override void visit(AST.FuncExp funcExp)
	{
		if (funcExp.fd is null)
			return;

		complexityStack[$ - 1]++;
		funcExp.fd.accept(this);
	}

	mixin VisitComplex!(AST.IfStatement, (AST.IfStatement statement, CyclomaticComplexityCheck visitor)
	{
		statement.condition.accept(visitor);
		statement.ifbody.accept(visitor);

		if (statement.elsebody !is null)
			statement.elsebody.accept(visitor);
	});

	mixin VisitComplex!(AST.CaseStatement, (AST.CaseStatement statement, CyclomaticComplexityCheck visitor)
	{
		statement.exp.accept(visitor);
		statement.statement.accept(visitor);
	});

	mixin VisitComplex!(AST.CaseRangeStatement, (AST.CaseRangeStatement statement, CyclomaticComplexityCheck visitor)
	{
		statement.first.accept(visitor);
		statement.last.accept(visitor);
		statement.statement.accept(visitor);
	});

	override void visit(AST.SwitchStatement switchStatement)
	{
		inLoop.assumeSafeAppend ~= false;
		scope (exit)
		inLoop.length--;

		switchStatement.condition.accept(this);
		switchStatement._body.accept(this);
	}

	override void visit(AST.BreakStatement breakStatement)
	{
		if (inLoop[$ - 1])
			complexityStack[$ - 1]++;
	}

	mixin VisitComplex!(AST.ReturnStatement, (AST.ReturnStatement statement, CyclomaticComplexityCheck visitor)
	{
		if (statement.exp !is null)
			statement.exp.accept(visitor);
	});

	mixin VisitComplex!(AST.ContinueStatement, (AST.ContinueStatement statement, CyclomaticComplexityCheck visitor)
	{
		return;
	});

	mixin VisitComplex!(AST.GotoStatement, (AST.GotoStatement statement, CyclomaticComplexityCheck visitor)
	{
		return;
	});

	override void visit(AST.TryCatchStatement tryCatchStatement)
	{
		tryCatchStatement._body.accept(this);

		if (tryCatchStatement.catches !is null)
		{
			foreach (catchStatement; *(tryCatchStatement.catches))
			{
				complexityStack[$ - 1]++;
				catchStatement.handler.accept(this);
			}
		}
	}

	mixin VisitComplex!(AST.TryFinallyStatement, (AST.TryFinallyStatement statement, CyclomaticComplexityCheck visitor)
	{
		statement._body.accept(visitor);
		statement.finalbody.accept(visitor);
	});

	mixin VisitComplex!(AST.ThrowExp, (AST.ThrowExp expression, CyclomaticComplexityCheck visitor)
	{
		expression.e1.accept(visitor);
	});

	mixin VisitComplex!(AST.LogicalExp, (AST.LogicalExp expression, CyclomaticComplexityCheck visitor)
	{
		expression.e1.accept(visitor);
		expression.e2.accept(visitor);
	});

	mixin VisitComplex!(AST.CondExp, (AST.CondExp CondExp, CyclomaticComplexityCheck visitor)
	{
		CondExp.econd.accept(visitor);
		CondExp.e1.accept(visitor);
		CondExp.e2.accept(visitor);
	});

	mixin VisitLoop!(AST.DoStatement, (AST.DoStatement statement, CyclomaticComplexityCheck visitor)
	{
		statement.condition.accept(visitor);
		statement._body.accept(visitor);
	});

	mixin VisitLoop!(AST.WhileStatement, (AST.WhileStatement statement, CyclomaticComplexityCheck visitor)
	{
		statement.condition.accept(visitor);
		statement._body.accept(visitor);
	});

	mixin VisitLoop!(AST.ForStatement, (AST.ForStatement statement, CyclomaticComplexityCheck visitor)
	{
		if (statement._init !is null)
			statement._init.accept(visitor);

		if (statement.condition !is null)
			statement.condition.accept(visitor);

		if (statement.increment !is null)
			statement.increment.accept(visitor);

		if (statement._body !is null)
			statement._body.accept(visitor);
	});

	override void visit(AST.StaticForeachStatement staticForeachStatement)
	{
		// StaticForeachStatement visit has to be overridden in order to avoid visiting
		// its forEachStatement member, which would increase the complexity.
		return;
	}

	mixin VisitLoop!(AST.ForeachRangeStatement, (AST.ForeachRangeStatement statement, CyclomaticComplexityCheck visitor)
	{
		if (statement._body !is null)
			statement._body.accept(visitor);

		if (statement.lwr !is null)
			statement.lwr.accept(visitor);

		if (statement.upr !is null)
			statement.upr.accept(visitor);
	});

	mixin VisitLoop!(AST.ForeachStatement, (AST.ForeachStatement statement, CyclomaticComplexityCheck visitor)
	{
		if (statement._body !is null)
			statement._body.accept(visitor);

		if (statement.aggr !is null)
			statement.aggr.accept(visitor);
	});

	private template VisitComplex(NodeType, alias visitMembersOf, int increase = 1)
	{
		override void visit(NodeType nodeType)
		{
			complexityStack[$ - 1] += increase;
			visitMembersOf(nodeType, this);
		}
	}

	private template VisitLoop(NodeType, alias visitMembersOf, int increase = 1)
	{
		override void visit(NodeType nodeType)
		{
			inLoop.assumeSafeAppend ~= true;
			scope (exit)
			inLoop.length--;

			complexityStack[$ - 1] += increase;
			visitMembersOf(nodeType, this);
		}
	}
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;
	import std.stdio : stderr;

	StaticAnalysisConfig sac = disabledConfig();
	sac.cyclomatic_complexity = Check.enabled;
	sac.max_cyclomatic_complexity = 0;

	assertAnalyzerWarningsDMD(q{
		// unit test
		unittest // [warn]: Cyclomatic complexity of this function is 1.
		{
			writeln("hello");
			writeln("world");
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		// goto, return
		void returnGoto() // [warn]: Cyclomatic complexity of this function is 3.
		{
			goto hello;
			int a = 0;
			a += 9;

		hello:
			return;
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		// if, else, ternary operator
		void ifElseTernary() // [warn]: Cyclomatic complexity of this function is 4.
		{
			if (1 > 2)
			{
				int a;
			}
			else if (2 > 1)
			{
				int b;
			}
			else
			{
				int c;
			}

			int d = true ? 1 : 2;
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		// static if and static foreach don't increase cyclomatic complexity
		void staticIfFor() // [warn]: Cyclomatic complexity of this function is 1.
		{
			static if (stuff)
				int a;

			int b;

			static foreach(i; 0 .. 10)
			{
				pragma(msg, i);
			}
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		// function literal (lambda)
		void lambda() // [warn]: Cyclomatic complexity of this function is 2.
		{
			auto x = (int a) => a + 1;
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		// loops: for, foreach, while, do - while
		void controlFlow() // [warn]: Cyclomatic complexity of this function is 7.
		{
			int x = 0;

			for (int i = 0; i < 100; i++)
			{
				i++;
			}

			foreach (i; 0 .. 2)
			{
				x += i;
				continue;
			}

			while (true)
			{
				break;
			}

			do
			{
				int x = 0;
			} while (true);
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		// switch - case
		void switchCaseCaseRange() // [warn]: Cyclomatic complexity of this function is 5.
		{
			switch (x)
			{
			case 1:
				break;
			case 2:
			case 3:
				break;
			case 7: .. case 10:
				break;
			default:
				break;
			}
			int a;
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		// if, else, logical expressions
		void ifConditions() // [warn]: Cyclomatic complexity of this function is 5.
		{
			if (true && false)
			{
				doX();
			}
			else if (true || false)
			{
				doY();
			}
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		// catch, throw
		void throwCatch() // [warn]: Cyclomatic complexity of this function is 5.
		{
			int x;
			try
			{
				x = 5;
			}
			catch (Exception e)
			{
				x = 7;
			}
			catch (Exception a)
			{
				x = 8;
			}
			catch (Exception x)
			{
				throw new Exception("Exception");
			}
			finally
			{
				x = 9;
			}
		}
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		// Template, other (tested) stuff
		bool shouldRun(check : BaseAnalyzer)( // [warn]: Cyclomatic complexity of this function is 20.
			string moduleName, const ref StaticAnalysisConfig config)
		{
			enum string a = check.name;

			if (mixin("config." ~ a) == Check.disabled)
				return false;

			if (!moduleName.length)
				return true;

			auto filters = mixin("config.filters." ~ a);

			if (filters.length == 0 || filters[0].length == 0)
				return true;

			auto includers = filters.filter!(f => f[0] == '+').map!(f => f[1..$]);
			auto excluders = filters.filter!(f => f[0] == '-').map!(f => f[1..$]);

			if (!excluders.empty && excluders.any!(s => moduleName.canFind(s)))
				return false;

			if (!includers.empty)
				return includers.any!(s => moduleName.canFind(s));

			return true;
		}
	}c, sac);

	stderr.writeln("Unittest for CyclomaticComplexityCheck passed.");
}
