// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.label_var_same_name_check;

import dsymbol.scope_ : Scope;
import dscanner.analysis.base;
import dscanner.analysis.helpers;
import std.conv : to;

import std.stdio : writeln;

/**
 * Checks for labels and variables that have the same name.
 */
extern(C++) class LabelVarNameCheck(AST) : BaseAnalyzerDmd!AST
{
	mixin AnalyzerInfo!"label_var_same_name_check";
	alias visit = BaseAnalyzerDmd!AST.visit;

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
	mixin ScopedVisit!(AST.ExpStatement);
	mixin ScopedVisit!(AST.ExpInitializer);
	mixin ScopedVisit!(AST.Type);

	mixin AggregateVisit!(AST.ClassDeclaration);
	mixin AggregateVisit!(AST.StructDeclaration);
	mixin AggregateVisit!(AST.InterfaceDeclaration);
	mixin AggregateVisit!(AST.UnionDeclaration);

	extern(D) this(string fileName)
	{
		super(fileName);
	}

	override void visit(AST.VarDeclaration vd)
	{
		import dmd.astenums : STC;

		if (!(vd.storage_class & STC.scope_))
			duplicateCheck(Thing(to!string(vd.ident.toChars()), vd.loc.linnum, vd.loc.charnum), false, conditionalDepth > 0);
		super.visit(vd);
	}

	override void visit(AST.LabelStatement ls)
	{
		duplicateCheck(Thing(to!string(ls.ident.toChars()), ls.loc.linnum, ls.loc.charnum), true, conditionalDepth > 0);
		super.visit(ls);
	}

	override void visit(AST.ConditionalStatement condition)
	{
		if (condition.elsebody)
			++conditionalDepth;
		
		super.visit(condition);
		
		if (condition.elsebody)
			--conditionalDepth;
	}

	override void visit(AST.ConditionalDeclaration condition)
	{
		++conditionalDepth;
		super.visit(condition);
		--conditionalDepth;
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

	extern(D) void duplicateCheck(const Thing id, bool fromLabel, bool isConditional)
	{
		import std.range : retro;

		size_t i;
		foreach (s; retro(stack))
		{
			string fqn = parentAggregateText ~ id.name;
			const(Thing)* thing = fqn in s;
			if (thing is null)
				currentScope[fqn] = Thing(fqn, id.line, id.column, !fromLabel /+, isConditional+/ );
			else if (i != 0 || !isConditional)
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

	int conditionalDepth;

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
	assertAnalyzerWarningsDMD(q{
void foo()
{
blah:
	int blah; // [warn]: Variable "blah" has the same name as a label defined on line 4.
}
int blah;
class C
{
	static if (stuff)
		int a;
	int a; // [warn]: Variable "C.a" has the same name as a variable defined on line 11.
}

class C
{
	static if (stuff)
		int a = 10;
	else
		int a = 20;
}

class C
{
	static if (stuff)
		int a = 10;
	else
		int a = 20;
	int a; // [warn]: Variable "C.a" has the same name as a variable defined on line 28.
}
template T(stuff)
{
	int b;
}

void main(string[] args)
{
	for (int a = 0; a < 10; a++)
		things(a);

	for (int a = 0; a < 10; a++)
		things(a);
	int b;
}

class C
{
	version (Windows)
		int c = 10;
	else
		int c = 20;
	int c; // [warn]: Variable "C.c" has the same name as a variable defined on line 51.
}

class C
{
	version(LittleEndian) { enum string NAME = "UTF-16LE"; }
	else version(BigEndian)    { enum string NAME = "UTF-16BE"; }
}

class C
{
	int a;
	struct A {int a;}
}

class C
{
	int a;
	struct A { struct A {int a;}}
}

class C
{
	int a;
	class A { class A {int a;}}
}

class C
{
	int a;
	interface A { interface A {int a;}}
}

class C
{
	interface A
	{
		int a;
		int a; // [warn]: Variable "C.A.a" has the same name as a variable defined on line 89.
	}
}

class C
{
	int aa;
	struct a { int a; }
}

}c, sac);
	stderr.writeln("Unittest for LabelVarNameCheck passed.");
}