// Copyright (c) 2018, dlang-community
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.redundant_storage_class;

import dscanner.analysis.base;
import dscanner.analysis.helpers;
import std.format;
import std.algorithm.comparison : among;
import std.algorithm.searching: all;
import dmd.astenums : STC;

/**
 * Checks for redundant storage classes such immutable and __gshared, static and __gshared
 */
extern(C++) class RedundantStorageClassCheck(AST) : BaseAnalyzerDmd
{
	mixin AnalyzerInfo!"redundant_storage_classes";
	alias visit = BaseAnalyzerDmd.visit;

	extern(D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.VarDeclaration d)
	{
		const(char[])[] stcAttributes = [];

		if (d.storage_class & STC.static_)
			stcAttributes ~= "static";

		if (d.storage_class & STC.immutable_)
			stcAttributes ~= "immutable";

		if (d.storage_class & STC.shared_)
			stcAttributes ~= "shared";

		if (d.storage_class & STC.gshared)
			stcAttributes ~= "__ghsared";

		if (stcAttributes.length > 1)
		{
			if (stcAttributes.length == 2 && (
					stcAttributes.all!(a => a.among("shared", "static")) ||
					stcAttributes.all!(a => a.among("static", "immutable"))
			))
				return;
			
			addErrorMessage(cast(ulong) d.loc.linnum, cast(ulong) d.loc.charnum,
							KEY, REDUNDANT_VARIABLE_ATTRIBUTES.format(d.ident.toString(), stcAttributes));
		}
	}

	override void visit(AST.StorageClassDeclaration scd)
	{
		if (!scd.decl)
			return;

		foreach (member; *scd.decl)
		{
			auto vd = member.isVarDeclaration();

			if (!vd)
				continue;

			const(char[])[] stcAttributes = [];

			if (vd.storage_class & STC.static_ || scd.stc & STC.static_)
				stcAttributes ~= "static";

			if (vd.storage_class & STC.immutable_ || scd.stc & STC.immutable_)
				stcAttributes ~= "immutable";

			if (vd.storage_class & STC.shared_ || scd.stc & STC.shared_)
				stcAttributes ~= "shared";

			if (vd.storage_class & STC.gshared || scd.stc & STC.gshared)
				stcAttributes ~= "__ghsared";

			if (stcAttributes.length > 1)
			{
				if (stcAttributes.length == 2 && (
						stcAttributes.all!(a => a.among("shared", "static")) ||
						stcAttributes.all!(a => a.among("static", "immutable"))
				))
					return;
				
				addErrorMessage(cast(ulong) vd.loc.linnum, cast(ulong) vd.loc.charnum,
								KEY, REDUNDANT_VARIABLE_ATTRIBUTES.format(vd.ident.toString(), stcAttributes));
			}
		}
	}

	private:
		enum KEY = "dscanner.unnecessary.duplicate_attribute";
		const(char[]) REDUNDANT_VARIABLE_ATTRIBUTES = "Variable declaration for `%s` has redundant attributes (%-(`%s`%|, %)).";
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import std.stdio : stderr;

	alias assertAnalyzerWarnings = assertAnalyzerWarningsDMD; 

	StaticAnalysisConfig sac = disabledConfig();
	sac.redundant_storage_classes = Check.enabled;

	// https://github.com/dlang-community/D-Scanner/issues/438
	assertAnalyzerWarnings(q{
		immutable int a;

		immutable shared int a; // [warn]: Variable declaration for `a` has redundant attributes (`immutable`, `shared`).
		shared immutable int a; // [warn]: Variable declaration for `a` has redundant attributes (`immutable`, `shared`).

		immutable __gshared int a; // [warn]: Variable declaration for `a` has redundant attributes (`immutable`, `__ghsared`).
		__gshared immutable int a; // [warn]: Variable declaration for `a` has redundant attributes (`immutable`, `__ghsared`).

		__gshared static int a; // [warn]: Variable declaration for `a` has redundant attributes (`static`, `__ghsared`).

		shared static int a;
		static shared int a;
		static immutable int a;
		immutable static int a;

		enum int a;
		extern(C++) immutable int a;
		immutable int function(immutable int, shared int) a;
	}c, sac);

	stderr.writeln("Unittest for RedundantStorageClassCheck passed.");
}