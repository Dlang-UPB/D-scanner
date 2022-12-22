//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.style;

import dscanner.analysis.base;
import dscanner.analysis.helpers;
import std.stdio;
import std.regex;


extern(C++) class StyleChecker(AST) : BaseAnalyzerDmd!AST
{
	mixin AnalyzerInfo!"style_check";
	alias visit = BaseAnalyzerDmd!AST.visit;

	extern(D) this(string fileName, AST.ModuleDeclaration* ptrMd, bool skipTests = false)
	{
		super(fileName, skipTests);

		if (ptrMd)
		{
			import std.conv : to;

			AST.ModuleDeclaration md = *ptrMd;

			if (md.id.toString().matchFirst(moduleNameRegex).length == 0)
				addErrorMessage(cast(ulong) md.loc.linnum, cast(ulong) md.loc.charnum, KEY,
							to!string("Module/package name '" ~ md.id.toString() ~ "' does not match style guidelines."));

			foreach (pkg; md.packages)
			{
				if (pkg.toString().matchFirst(moduleNameRegex).length == 0)
					addErrorMessage(cast(ulong) md.loc.linnum, cast(ulong) md.loc.charnum, KEY,
							to!string("Module/package name '" ~ pkg.toString() ~ "' does not match style guidelines."));
			}
		}

	}

	override void visit(AST.LinkDeclaration ld)
	{
		import dmd.astenums : LINK;

		if (ld.decl)
            foreach (de; *ld.decl)
			{
				auto fd = de.isFuncDeclaration();
				if (fd && !fd.fbody && ld.linkage == LINK.windows)
					continue;
			
				de.accept(this);
			}
	}

	override void visit(AST.FuncDeclaration d)
	{
		checkLowercaseName("Function", d);
		super.visit(d);
	}

	override void visit(AST.VarDeclaration d)
	{
		import dmd.astenums : STC;

		// ditch enum variables as these have different style guidelines
		if (!(d.storage_class & STC.manifest))
			checkLowercaseName("Variable", d);
		
		super.visit(d);
	}

	override void visit(AST.TemplateDeclaration d)
	{
		checkLowercaseName("Template", d);
		super.visit(d);
	}

	override void visit(AST.ClassDeclaration d)
	{
		checkAggregateName("Class", d);
		super.visit(d);
	}

	override void visit(AST.StructDeclaration d)
	{
		checkAggregateName("Struct", d);
		super.visit(d);
	}

	override void visit(AST.InterfaceDeclaration d)
	{
		checkAggregateName("Interface", d);
		super.visit(d);
	}

	override void visit(AST.UnionDeclaration d)
	{
		checkAggregateName("Union", d);
		super.visit(d);
	}

	override void visit(AST.EnumDeclaration d)
	{
		checkAggregateName("Enum", d);
		super.visit(d);
	}

	extern(D) void checkLowercaseName(string type, AST.Dsymbol d)
	{
		import std.conv : to;

		if (d.ident && d.ident.toString().matchFirst(varFunNameRegex).length == 0)
			addErrorMessage(cast(ulong) d.loc.linnum, cast(ulong) d.loc.charnum, KEY,
							to!string(type ~ " name '" ~ d.ident.toString() ~ "' does not match style guidelines."));
	}

	extern(D) void checkAggregateName(string aggregateType, AST.ScopeDsymbol d)
	{

		import std.conv : to;

		if (d.ident && d.ident.toString().matchFirst(aggregateNameRegex).length == 0)
			addErrorMessage(cast(ulong) d.loc.linnum, cast(ulong) d.loc.charnum, KEY,
							to!string(aggregateType ~ " name '" ~ d.ident.toString() ~ "' does not match style guidelines."));
	}

	private:
		enum KEY = "dscanner.suspicious.style_check";
		enum varFunNameRegex = `^([\p{Ll}_][_\w\d]*|[\p{Lu}\d_]+)$`;
		enum aggregateNameRegex = `^\p{Lu}[\w\d]*$`;
		enum moduleNameRegex = `^[\p{Ll}_\d]+$`;
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;

	StaticAnalysisConfig sac = disabledConfig();
	sac.style_check = Check.enabled;

	alias assertAnalyzerWarnings = assertAnalyzerWarningsDMD;

	assertAnalyzerWarnings(q{
		module AMODULE; // [warn]: Module/package name 'AMODULE' does not match style guidelines.

		bool A_VARIABLE; // FIXME:
		bool a_variable; // ok
		bool aVariable; // ok

		void A_FUNCTION() {} // FIXME:
		class cat {} // [warn]: Class name 'cat' does not match style guidelines.
		interface puma {} // [warn]: Interface name 'puma' does not match style guidelines.
		struct dog {} // [warn]: Struct name 'dog' does not match style guidelines.
		enum racoon { a } // [warn]: Enum name 'racoon' does not match style guidelines.
		enum bool something = false;
		enum bool someThing = false;
		enum Cat { fritz, }
		enum Cat = Cat.fritz;
	}c, sac);

	assertAnalyzerWarnings(q{
		extern(Windows)
		{
			bool Fun0();
			extern(Windows) bool Fun1();
		}
	}c, sac);

	assertAnalyzerWarnings(q{
		extern(Windows)
		{
			extern(D) bool Fun2(); // [warn]: Function name 'Fun2' does not match style guidelines.
			bool Fun3();
		}
	}c, sac);

	assertAnalyzerWarnings(q{
		extern(Windows)
		{
			extern(C):
				extern(D) bool Fun4(); // [warn]: Function name 'Fun4' does not match style guidelines.
				bool Fun5(); // [warn]: Function name 'Fun5' does not match style guidelines.
		}
	}c, sac);

	assertAnalyzerWarnings(q{
		extern(Windows):
			bool Fun6();
			bool Fun7();
		extern(D):
			void okOkay();
			void NotReallyOkay(); // [warn]: Function name 'NotReallyOkay' does not match style guidelines.
	}c, sac);

	assertAnalyzerWarnings(q{
		extern(Windows):
			bool WinButWithBody(){} // [warn]: Function name 'WinButWithBody' does not match style guidelines.
	}c, sac);

	stderr.writeln("Unittest for StyleChecker passed.");
}
