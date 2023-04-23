// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.label_var_same_name_check;

import dscanner.analysis.base;
import dscanner.analysis.helpers;
import std.conv : to;
import dmd.cond : Include;
import dmd.root.array : peekSlice;

import std.stdio : writeln;

/**
 * Checks for labels and variables that have the same name.
 */
extern(C++) class LabelVarNameCheck(AST) : BaseAnalyzerDmd
{
	mixin AnalyzerInfo!"label_var_same_name_check";
	alias visit = BaseAnalyzerDmd.visit;

	mixin ScopedVisit!(AST.Module);
	mixin ScopedVisit!(AST.TemplateDeclaration);
	mixin ScopedVisit!(AST.IfStatement);
	mixin ScopedVisit!(AST.WhileStatement);
	mixin ScopedVisit!(AST.ForStatement);
	mixin ScopedVisit!(AST.CaseStatement);
	mixin ScopedVisit!(AST.ForeachStatement);
	mixin ScopedVisit!(AST.ForeachRangeStatement);
	mixin ScopedVisit!(AST.ScopeStatement);
	mixin ScopedVisit!(AST.UnitTestDeclaration);
	mixin ScopedVisit!(AST.FuncDeclaration);
	mixin ScopedVisit!(AST.FuncLiteralDeclaration);
	mixin ScopedVisit!(AST.CtorDeclaration);

	mixin AggregateVisit!(AST.ClassDeclaration);
	mixin AggregateVisit!(AST.StructDeclaration);
	mixin AggregateVisit!(AST.InterfaceDeclaration);
	mixin AggregateVisit!(AST.UnionDeclaration);

	extern(D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.VarDeclaration vd)
	{
		import dmd.astenums : STC;

		if (!(vd.storage_class & STC.scope_))
			duplicateCheck(Thing(to!string(vd.ident.toChars()), vd.loc.linnum, vd.loc.charnum), false);
		super.visit(vd);
	}

	override void visit(AST.LabelStatement ls)
	{
		duplicateCheck(Thing(to!string(ls.ident.toChars()), ls.loc.linnum, ls.loc.charnum), true);
		super.visit(ls);
	}

	override void visit(AST.ConditionalDeclaration d)
	{
        if (d.condition.inc == Include.yes)
			foreach (de; d.decl.peekSlice())
				de.accept(this);
        else if (d.condition.inc == Include.no)
			foreach (de; d.elsedecl.peekSlice())
				de.accept(this);
	}

	override void visit(AST.AnonDeclaration ad)
	{
		pushScope();
		pushAggregateName("", ad.loc.linnum, ad.loc.charnum);
		super.visit(ad);
		popScope();
		popAggregateName();
	}

private:

	extern(D) Thing[string][] stack;

	template AggregateVisit(NodeType)
	{
		override void visit(NodeType n)
		{
			pushScope();
			pushAggregateName(to!string(n.ident.toString()), n.loc.linnum, n.loc.charnum);
			super.visit(n);
			popScope();
			popAggregateName();
		}
	}

	template ScopedVisit(NodeType)
	{
		override void visit(NodeType n)
		{
			pushScope();
			super.visit(n);
			popScope();
		}
	}

	extern(D) void duplicateCheck(const Thing id, bool fromLabel)
	{
		import std.range : retro;

		size_t i;
		foreach (s; retro(stack))
		{
			string fqn = parentAggregateText ~ id.name;
			const(Thing)* thing = fqn in s;
			if (thing is null)
				currentScope[fqn] = Thing(fqn, id.line, id.column, !fromLabel);
			else
			{
				immutable thisKind = fromLabel ? "Label" : "Variable";
				immutable otherKind = thing.isVar ? "variable" : "label";
				addErrorMessage(id.line, id.column, "dscanner.suspicious.label_var_same_name",
						thisKind ~ " \"" ~ fqn ~ "\" has the same name as a "
						~ otherKind ~ " defined on line " ~ to!string(thing.line) ~ ".");
			}
			++i;
		}
	}

	extern(D) static struct Thing
	{
		string name;
		size_t line;
		size_t column;
		bool isVar;
	}

	extern(D) ref currentScope() @property
	{
		return stack[$ - 1];
	}

	extern(D) void pushScope()
	{
		stack.length++;
	}

	extern(D) void popScope()
	{
		stack.length--;
	}

	extern(D) void pushAggregateName(string name, size_t line, size_t column)
	{
		parentAggregates ~= Thing(name, line, column);
		updateAggregateText();
	}

	extern(D) void popAggregateName()
	{
		parentAggregates.length -= 1;
		updateAggregateText();
	}

	extern(D) void updateAggregateText()
	{
		import std.algorithm : map;
		import std.array : join;

		if (parentAggregates.length)
			parentAggregateText = parentAggregates.map!(a => a.name).join(".") ~ ".";
		else
			parentAggregateText = "";
	}

	extern(D) Thing[] parentAggregates;
	extern(D) string parentAggregateText;
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import std.stdio : stderr;

	StaticAnalysisConfig sac = disabledConfig();
	sac.label_var_same_name_check = Check.enabled;
	assertAnalyzerWarningsDMD(q{unittest
{
blah:
	int blah; // [warn]: Variable "blah" has the same name as a label defined on line 3.
}
int blah;
unittest
{
	static if (true)
		int a;
	void foo()
	{
		int a; // [warn]: Variable "a" has the same name as a variable defined on line 10.
	}
}

unittest
{
	static if (true)
		int a = 10;
	else
		int a = 20;
}

unittest
{
	static if (true)
		int a = 10;
	else
		int a = 20;
	
	void main()
	{
		int a; // [warn]: Variable "a" has the same name as a variable defined on line 28.
	}
}
template T(stuff)
{
	int b;
}

void main(string[] args)
{
	void things(int a) {}

	for (int a = 0; a < 10; a++)
		things(a);

	for (int a = 0; a < 10; a++)
		things(a);
	int b;
}

unittest
{
	version (Windows)
		int c = 10;
	else
		int c = 20;
	
	void main()
	{
		int c; // [warn]: Variable "c" has the same name as a variable defined on line 59.
	}
}

unittest
{
	version(LittleEndian) { enum string NAME = "UTF-16LE"; }
	else version(BigEndian)    { enum string NAME = "UTF-16BE"; }
}

unittest
{
	int a;
	struct A {int a;}
}

unittest
{
	int a;
	struct A { struct A {int a;}}
}

unittest
{
	int a;
	class A { class A {int a;}}
}

unittest
{
	int a;
	class A { class B {int a;}}
}

unittest
{
	class A
	{
		int a;
		void foo()
		{
			int a; // [warn]: Variable "A.a" has the same name as a variable defined on line 101.
		}
	}
}

unittest
{
	int aa;
	struct a { int a; }
}
}c, sac, true);
	stderr.writeln("Unittest for LabelVarNameCheck passed.");
}