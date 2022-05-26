//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.objectconst;

import dscanner.analysis.base;
import dscanner.analysis.helpers;
import std.stdio;

extern(C++) class ObjectConstCheck(AST) : BaseAnalyzerDmd!AST
{
	mixin AnalyzerInfo!"object_const_check";
	alias visit = BaseAnalyzerDmd!AST.visit;

	// mixin visitTemplate!AST.ClassDeclaration;
	// mixin visitTemplate!AST.InterfaceDeclaration;
	// mixin visitTemplate!AST.UnionDeclaration;
	// mixin visitTemplate!AST.StructDeclaration;

	override void visit(AST.ClassDeclaration cd)
	{
		inAggregate = true;
		super.visit(cd);
		inAggregate = false;
	}

	override void visit(AST.InterfaceDeclaration cd)
	{
		inAggregate = true;
		super.visit(cd);
		inAggregate = false;
	}

	override void visit(AST.UnionDeclaration cd)
	{
		inAggregate = true;
		super.visit(cd);
		inAggregate = false;
	}

	override void visit(AST.StructDeclaration cd)
	{
		inAggregate = true;
		super.visit(cd);
		inAggregate = false;
	}

	extern(D) this(string fileName)
	{
		this.inConstBlock = false;
		super(fileName);
	}

	override void visit(AST.StorageClassDeclaration scd)
	{
		import dmd.astenums : STC;

		if (scd.stc & STC.const_ || scd.stc & STC.immutable_ || scd.stc & STC.wild)
			inConstBlock = true;

		foreach(de; *scd.decl)
		{
			de.accept(this);
		}

		inConstBlock = false;
	}

	override void visit(AST.FuncDeclaration ed)
    {
		import dmd.astenums : MODFlags, STC;

		if (!ed.type.mod == MODFlags.const_ && isInteresting(ed.ident.toString()) && 
			inAggregate && !inConstBlock && !(ed.storage_class & STC.disable))
				addErrorMessage(cast(ulong) ed.loc.linnum, cast(ulong) ed.loc.charnum, KEY,
						"Methods 'opCmp', 'toHash', 'opEquals', 'opCast', and/or 'toString' are non-const.");
		
		super.visit(ed);

	}

	extern(D) private static bool isInteresting(const char[] name)
	{
		return name == "opCmp" || name == "toHash" || name == "opEquals"
			|| name == "toString" || name == "opCast";
	}

	private bool inConstBlock;
	private enum KEY = "dscanner.suspicious.object_const";
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;

	StaticAnalysisConfig sac = disabledConfig();
	sac.object_const_check = Check.enabled;
	assertAnalyzerWarningsDMD(q{
		void testConsts()
		{
			// Will be ok because all are declared const/immutable
			class Cat
			{
				const bool opEquals(Object a, Object b) // ok
				{
					return true;
				}

				const int opCmp(Object o) // ok
				{
					return 1;
				}

				immutable hash_t toHash() // ok
				{
					return 0;
				}

				const string toString() // ok
				{
					return "Cat";
				}
			}

			class Bat
			{
				const: override string toString() { return "foo"; } // ok
			}

			class Fox
			{
				inout { override string toString() { return "foo"; } } // ok
			}

			class Rat
			{
				bool opEquals(Object a, Object b) @disable; // ok
			}

			class Ant
			{
				@disable bool opEquals(Object a, Object b); // ok
			}

			// Will warn, because none are const
			class Dog
			{
				bool opEquals(Object a, Object b) // [warn]: Methods 'opCmp', 'toHash', 'opEquals', 'opCast', and/or 'toString' are non-const.
				{
					return true;
				}

				int opCmp(Object o) // [warn]: Methods 'opCmp', 'toHash', 'opEquals', 'opCast', and/or 'toString' are non-const.
				{
					return 1;
				}

				hash_t toHash() // [warn]: Methods 'opCmp', 'toHash', 'opEquals', 'opCast', and/or 'toString' are non-const.
				{
					return 0;
				}

				string toString() // [warn]: Methods 'opCmp', 'toHash', 'opEquals', 'opCast', and/or 'toString' are non-const.
				{
					return "Dog";
				}
			}
		}
	}c, sac);

	stderr.writeln("Unittest for ObjectConstCheck passed.");
}
