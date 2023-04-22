//          Copyright Brian Schott (Hackerpilot) 2015.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)
module dscanner.analysis.unmodified;

import dscanner.analysis.base;
import std.container;

/**
 * Checks for variables that could have been declared const or immutable
 */
extern(C++) class UnmodifiedFinder(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"could_be_immutable_check";

	extern(D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.Module m)
	{
		pushScope();
		super.visit(m);
		popScope();
	}

	override void visit(AST.VarDeclaration d)
	{
		import dmd.astenums : STC, MODFlags;
		import std.algorithm.searching : startsWith;
		import std.conv : to;

		if (tree.length == 1)
			return;

		if (d.storage_class & STC.auto_)
			return;

		/* If variable is already declared const/immutable/enum, the entire scope
		 *	is declared const/immutable, or the variable is a property of an aggregate,
		 *	there is no need to investigate it
		 */
		if (d.storage_class & STC.immutable_ || d.storage_class & STC.const_ ||
			d.storage_class & STC.manifest|| inAggregate || isImmutable ||
			(d.type && (d.type.isConst() || d.type.isImmutable())))
				return;

		/* Do the same check for pointer types */
		if (d.type)
		{
			auto tp = d.type.isTypePointer();

			if (tp && tp.next && (tp.next.isConst() || tp.next.isImmutable()))
				return;
		}

		/* Also ditch variables initialized with `new` or `cast` */
		if (d._init && (startsWith(to!string(d._init.toChars()), "new") ||
						startsWith(to!string(d._init.toChars()), "cast")))
							return;

		tree[$ - 1].insert(new VariableInfo(d.ident.toString().dup, d.loc.linnum,
						d.loc.charnum, false));

		super.visit(d);
	}

	override void visit(AST.ReturnStatement s)
	{
		if (s.exp) if (auto ie = s.exp.isIdentifierExp())
			variableMightBeModified(ie.ident.toString().dup);
	}

	override void visit(AST.CallExp e)
	{
		if (e.arguments)
			foreach(exp; *e.arguments)
				if (auto ie = exp.isIdentifierExp()) variableMightBeModified(ie.ident.toString().dup);
				

		super.visit(e);
	}

	override void visit(AST.NewExp e)
	{
		if (e.arguments)
			foreach(exp; *e.arguments)
				if (auto ie = exp.isIdentifierExp()) variableMightBeModified(ie.ident.toString().dup); 

		super.visit(e);
	}

	static foreach (node; varChangingNodes)
				mixin VariableChanged!(mixin(node));

	static foreach (node; aggregateNodes)
				mixin InAggregate!(mixin(node));

	static foreach (node; scopedVisitNodes)
				mixin ScopedVisit!(mixin(node));

	private enum KEY = "dscanner.performance.enum_array_literal";

	private:
		template VariableChanged(T)
		{
			override void visit(T t)
			{
				/* Handle a[] = ... */
				if (auto ae = t.e1.isArrayExp()) if (auto ie = ae.e1.isIdentifierExp())
					variableMightBeModified(ie.ident.toString().dup);

				if (auto ie = t.e1.isIdentifierExp())
					variableMightBeModified(ie.ident.toString().dup);

				super.visit(t);
			}
		}

		template InAggregate(T)
		{
			override void visit(T t)
			{
				pushScope();
				immutable oldInAggregate = inAggregate;
				inAggregate = 1;
				super.visit(t);
				inAggregate = oldInAggregate;
				popScope();
			}
		}

		template ScopedVisit(T)
		{
			override void visit(T t)
			{
				pushScope();
				immutable oldInAggregate = inAggregate;
				inAggregate = 0;
				super.visit(t);
				inAggregate = oldInAggregate;
				popScope();
			}
		}

		extern(D) static immutable varChangingNodes = ["AST.AssignExp", "AST.PostExp", "AST.PreExp", "AST.CatAssignExp",
						"AST.AddAssignExp", "AST.MinAssignExp", "AST.MulAssignExp", "AST.DivAssignExp", "AST.ModAssignExp",
						"AST.AndAssignExp", "AST.OrAssignExp", "AST.XorAssignExp", "AST.PowAssignExp", "AST.ShlAssignExp",
						"AST.ShrAssignExp", "AST.UshrAssignExp", "AST.DotIdExp"];

		extern(D) static immutable aggregateNodes = ["AST.ClassDeclaration", "AST.StructDeclaration", "AST.UnionDeclaration",
									"AST.TemplateDeclaration"];

		extern(D) static immutable scopedVisitNodes = ["AST.FuncDeclaration", "AST.IfStatement", "AST.WhileStatement",
									"AST.ForStatement", "AST.ForeachStatement", "AST.ScopeStatement"];

		static struct VariableInfo
		{
			string name;
			size_t line;
			size_t column;
			bool isValueType;
		}

		void popScope()
		{
			foreach (vi; tree[$ - 1])
			{
				immutable string errorMessage = "Variable " ~ vi.name
					~ " is never modified and could have been declared const or immutable.";
				addErrorMessage(vi.line, vi.column, "dscanner.suspicious.unmodified", errorMessage);
			}
			tree = tree[0 .. $ - 1];
		}

		void pushScope()
		{
			tree ~= new RedBlackTree!(VariableInfo*, "a.name < b.name");
		}

		extern(D) void variableMightBeModified(string name)
		{
			size_t index = tree.length - 1;
			auto vi = VariableInfo(name);
			
			while (true)
			{
				if (tree[index].removeKey(&vi) != 0 || index == 0)
					break;
				index--;
			}
		}

		int inAggregate;

		int interest;

		int guaranteeUse;

		int isImmutable;

		bool inAsm;

		RedBlackTree!(VariableInfo*, "a.name < b.name")[] tree;
}

@system unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarnings = assertAnalyzerWarningsDMD;
	import std.stdio : stderr;
	import std.format : format;

	StaticAnalysisConfig sac = disabledConfig();
	sac.could_be_immutable_check = Check.enabled;

	// fails

	assertAnalyzerWarnings(q{
		void foo(){int i = 1;} // [warn]: Variable i is never modified and could have been declared const or immutable.
	}, sac);

	// pass

	assertAnalyzerWarnings(q{
		void foo(){const(int) i;}
	}, sac);

	assertAnalyzerWarnings(q{
		void foo(){immutable(int)* i;}
	}, sac);

	assertAnalyzerWarnings(q{
		void foo(){enum i = 1;}
	}, sac);

	assertAnalyzerWarnings(q{
		void foo(){E e = new E;}
	}, sac);

	assertAnalyzerWarnings(q{
		void foo(){auto e = new E;}
	}, sac);

	assertAnalyzerWarnings(q{
		void issue640()
		{
			size_t i1;
			new Foo(i1);

			size_t i2;
			foo(i2);
		}
	}, sac);
}

