// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.imports_sortedness;

import dscanner.analysis.base;

/**
 * Checks the sortedness of module imports
 */
extern(C++) class ImportSortednessCheck(AST) : BaseAnalyzerDmd!AST
{
	enum string KEY = "dscanner.style.imports_sortedness";
	enum string MESSAGE = "The imports are not sorted in alphabetical order";
	mixin AnalyzerInfo!"imports_sortedness";
	alias visit = BaseAnalyzerDmd!AST.visit;

	///
	extern(D) this(string fileName)
	{
		super(fileName);
	}

	mixin ScopedVisit!(AST.StructDeclaration);
	mixin ScopedVisit!(AST.FuncDeclaration);
	mixin ScopedVisit!(AST.InterfaceDeclaration);
	mixin ScopedVisit!(AST.UnionDeclaration);
	mixin ScopedVisit!(AST.TemplateDeclaration);
	mixin ScopedVisit!(AST.IfStatement);
	mixin ScopedVisit!(AST.WhileStatement);
	mixin ScopedVisit!(AST.ForStatement);
	mixin ScopedVisit!(AST.ForeachStatement);
	mixin ScopedVisit!(AST.ScopeStatement);
	mixin ScopedVisit!(AST.ConditionalDeclaration);


	override void visit(AST.VarDeclaration vd)
	{
		imports[level] = [];
	}

	override void visit(AST.Import i)
	{
		import std.algorithm : map;
		import std.array : join;
		import std.conv : to;

		string importModuleName = i.packages.map!(a => a.toString().dup).join(".");

		if (importModuleName != "")
			importModuleName ~= "." ~ i.id.toString();
		else
			importModuleName ~= i.id.toString();

		if (i.names.length)
		{
			foreach (name; i.names)
			{
				string aux = to!string(importModuleName ~ "-" ~ name.toString());
				addImport(aux, i);
			}
		}
		else addImport(importModuleName, i);
	}

private:
	enum maxDepth = 20;
	int level;
	string[][int] imports;
	bool[maxDepth] levelAvailable;

	template ScopedVisit(NodeType)
	{
		override void visit(NodeType n)
		{
			if (level >= maxDepth)
				return;

			imports[level] = [];
			imports[++level] = [];
			levelAvailable[level] = true;
			super.visit(n);
			level--;
		}
	}

	extern(D) void addImport(string importModuleName, AST.Import i)
	{
		import std.uni : sicmp;

		if (!levelAvailable[level])
		{
			imports[level] = [];
			levelAvailable[level] = true;
		}

		if (imports[level].length > 0 && imports[level][$ - 1].sicmp(importModuleName) > 0)
		{
			addErrorMessage(cast(ulong) i.loc.linnum, cast(ulong) i.loc.charnum, KEY, MESSAGE);
		}
		else
		{
			imports[level] ~= importModuleName;
		}
	}
}

unittest
{
	import std.stdio : stderr;
	import std.format : format;
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;

	StaticAnalysisConfig sac = disabledConfig();
	sac.imports_sortedness = Check.enabled;

	assertAnalyzerWarningsDMD(q{
		import bar.foo;
		import foo.bar;
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		import foo.bar;
		import bar.foo; // [warn]: %s
	}c.format(
		"The imports are not sorted in alphabetical order",
	), sac);

	assertAnalyzerWarningsDMD(q{
		import c;
		import c.b;
		import c.a; // [warn]: %s
		import d.a;
		import d; // [warn]: %s
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	assertAnalyzerWarningsDMD(q{
		import a.b, a.c, a.d;
		import a.b, a.d, a.c; // [warn]: %s
		import a.c, a.b, a.c; // [warn]: %s
		import foo.bar, bar.foo; // [warn]: %s
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	// multiple items out of order
	assertAnalyzerWarningsDMD(q{
		import foo.bar;
		import bar.foo; // [warn]: %s
		import bar.bar.foo; // [warn]: %s
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	assertAnalyzerWarningsDMD(q{
		import test : bar;
		import test : foo;
	}c, sac);

	// selective imports
	assertAnalyzerWarningsDMD(q{
		import test : foo;
		import test : bar; // [warn]: %s
	}c.format(
		"The imports are not sorted in alphabetical order",
	), sac);

	// selective imports
	assertAnalyzerWarningsDMD(q{
		import test : foo, bar; // [warn]: %s
	}c.format(
		"The imports are not sorted in alphabetical order",
	), sac);

	assertAnalyzerWarningsDMD(q{
		import b;
		import c : foo;
		import c : bar; // [warn]: %s
		import a; // [warn]: %s
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	assertAnalyzerWarningsDMD(q{
		import c;
		import c : bar;
		import d : bar;
		import d; // [warn]: %s
		import a : bar; // [warn]: %s
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	assertAnalyzerWarningsDMD(q{
		import t0;
		import t1 : a, b = foo;
		import t2;
	}c, sac);

	assertAnalyzerWarningsDMD(q{
		import t1 : a, b = foo;
		import t1 : b, a = foo; // [warn]: %s
		import t0 : a, b = foo; // [warn]: %s
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	// local imports in functions
	assertAnalyzerWarningsDMD(q{
		import t2;
		import t1; // [warn]: %s
		void foo()
		{
			import f2;
			import f1; // [warn]: %s
			import f3;
		}
		void bar()
		{
			import f1;
			import f2;
		}
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	// local imports in scopes
	assertAnalyzerWarningsDMD(q{
		import t2;
		import t1; // [warn]: %s
		void foo()
		{
			import f2;
			import f1; // [warn]: %s
			import f3;
			{
				import f2;
				import f1; // [warn]: %s
				import f3;
			}
			{
				import f1;
				import f2;
				import f3;
			}
		}
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	// local imports in functions
	assertAnalyzerWarningsDMD(q{
		import t2;
		import t1; // [warn]: %s
		void foo()
		{
			import f2;
			import f1; // [warn]: %s
			import f3;
			while (true) {
				import f2;
				import f1; // [warn]: %s
				import f3;
			}
			for (;;) {
				import f1;
				import f2;
				import f3;
			}
			foreach (el; arr) {
				import f2;
				import f1; // [warn]: %s
				import f3;
			}
		}
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	// nested scopes
	assertAnalyzerWarningsDMD(q{
		import t2;
		import t1; // [warn]: %s
		void foo()
		{
			import f2;
			import f1; // [warn]: %s
			import f3;
			{
				import f2;
				import f1; // [warn]: %s
				import f3;
				{
					import f2;
					import f1; // [warn]: %s
					import f3;
					{
						import f2;
						import f1; // [warn]: %s
						import f3;
					}
				}
			}
		}
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	// local imports in functions
	assertAnalyzerWarningsDMD(q{
		import t2;
		import t1; // [warn]: %s
		struct foo()
		{
			import f2;
			import f1; // [warn]: %s
			import f3;
		}
		class bar()
		{
			import f1;
			import f2;
		}
	}c.format(
		"The imports are not sorted in alphabetical order",
		"The imports are not sorted in alphabetical order",
	), sac);

	// issue 422 - sorted imports with :
	assertAnalyzerWarningsDMD(q{
		import foo.bar : bar;
		import foo.barbar;
	}, sac);

	// issue 422 - sorted imports with :
	assertAnalyzerWarningsDMD(q{
		import foo;
		import foo.bar;
		import fooa;
		import std.range : Take;
		import std.range.primitives : isInputRange, walkLength;
	}, sac);

	// condition declaration
	assertAnalyzerWarningsDMD(q{
		import t2;
		version(unittest)
		{
			import t1;
		}
	}, sac);

	// if statements
	assertAnalyzerWarningsDMD(q{
	unittest
	{
		import t2;
		if (true)
		{
			import t1;
		}
	}
	}, sac);

	// intermediate imports
	assertAnalyzerWarningsDMD(q{
	unittest
	{
		import t2;
		int a = 1;
		import t1;
	}
	}, sac);

	stderr.writeln("Unittest for ImportSortednessCheck passed.");
}
