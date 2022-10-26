//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.local_imports;

import dscanner.analysis.base;
import dscanner.analysis.helpers;
import dsymbol.scope_;

import std.stdio : writeln;

/**
 * Checks for local imports that import all symbols.
 * See_also: $(LINK https://issues.dlang.org/show_bug.cgi?id=10378)
 */
extern(C++) class LocalImportCheck(AST) : BaseAnalyzerDmd!AST
{
	mixin AnalyzerInfo!"local_import_check";
	alias visit = BaseAnalyzerDmd!AST.visit;

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
	mixin ScopedVisit!(AST.UnitTestDeclaration);

	extern(D) this(string fileName)
	{
		super(fileName);
		this.localImport = false;
		writeln("In local imports constructor");
	}

	override void visit(AST.Import i)
	{

		writeln("IN VISIT IMPORT");

		if (!i.isstatic && localImport && i.names.length == 0 && !i.aliasId)
			addErrorMessage(cast(ulong) i.loc.linnum, cast(ulong) i.loc.charnum, KEY, MESSAGE);
	}

private:
	template ScopedVisit(NodeType)
	{
		override void visit(NodeType n)
		{
			bool prevState = localImport;
			localImport = true;
			super.visit(n);
			localImport = prevState;
		}
	}

	bool localImport;
	enum KEY = "dscanner.suspicious.local_imports";
	enum MESSAGE = "Local imports should specify the symbols being imported to avoid hiding local symbols.";
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import std.stdio : stderr;

	StaticAnalysisConfig sac = disabledConfig();
	sac.local_import_check = Check.enabled;

	assertAnalyzerWarningsDMD(q{
		import std.experimental;

		void foo()
		{
			import std.stdio; // [warn]: Local imports should specify the symbols being imported to avoid hiding local symbols.
			import std.fish : scales, head;
			import DAGRON = std.experimental.dragon;

			if (1) {

			} else {
				import foo.bar; // [warn]: Local imports should specify the symbols being imported to avoid hiding local symbols.
			}

			foreach (i; [1, 2, 3])
			{
				import foo.bar; // [warn]: Local imports should specify the symbols being imported to avoid hiding local symbols.
				import std.stdio : writeln;
			}
		}

		import std.experimental.dragon;
	}c, sac);

	stderr.writeln("Unittest for LocalImportCheck passed.");
}
