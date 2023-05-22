//          Copyright Basile Burg 2017.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//
module dscanner.analysis.vcall_in_ctor;

import dscanner.analysis.base;
import dscanner.utils;
import dmd.astenums : STC; 

/**
 * Checks virtual calls from the constructor to methods defined in the same class.
 *
 * When not used carefully, virtual calls from constructors can lead to a call
 * in a derived instance that's not yet constructed.
 */
extern(C++) class VcallCtorChecker(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"vcall_in_ctor";

	extern(D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.ClassDeclaration d)
	{
		if (d.members)
			foreach (s; *d.members)
			{
				if (s.isCtorDeclaration())
					inClassCtor = true;
				s.accept(this);
				if (s.isCtorDeclaration())
					inClassCtor = false;
			}
	}

	override void visit(AST.CallExp e)
	{
		if (inClassCtor && e.f && e.f.isVirtualMethod())
			addErrorMessage(cast(ulong) e.loc.linnum, cast(ulong) e.loc.charnum, KEY, MSG);
	}

	bool inClassCtor;
	private enum MSG = "a virtual call inside a constructor may lead to"
		~ " unexpected results in the derived classes";
	private enum string KEY = "dscanner.vcall_ctor";
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarnings = assertAnalyzerWarningsDMD;
	import std.stdio : stderr;
	import std.format : format;

	StaticAnalysisConfig sac = disabledConfig();
	sac.vcall_in_ctor = Check.enabled;

	enum MSG = "a virtual call inside a constructor may lead to"
		~ " unexpected results in the derived classes";

	// fails
	assertAnalyzerWarnings(q{
		class Bar
		{
			this(){foo();} // [warn]: %s
			private:
			public
			void foo(){}

		}
	}c.format(MSG), sac, true);

	assertAnalyzerWarnings(q{
		class Bar
		{
			this()
			{
				foo(); // [warn]: %s
				foo(); // [warn]: %s
				bar();
			}
			private: void bar();
			public{void foo(){}}
		}
	}c.format(MSG,MSG), sac, true);

	// passes
	assertAnalyzerWarnings(q{
		class Bar
		{
			this(){foo();}
			private void foo(){}
		}
	}, sac, true);

	assertAnalyzerWarnings(q{
		class Bar
		{
			this(){foo();}
			private {void foo(){}}
		}
	}, sac, true);

	assertAnalyzerWarnings(q{
		interface I
		{
			final void foo() {}	
		}

		class C : I
		{
			this() {foo();}
		}
	}, sac, true);

	assertAnalyzerWarnings(q{
		final class Bar
		{
			public:
			this(){foo();}
			void foo(){}
		}
	}, sac, true);

	assertAnalyzerWarnings(q{
		class Bar
		{
			public:
			this(){foo!int();}
			void foo(T)(){}
		}
	}, sac, true);

	assertAnalyzerWarnings(q{
		class Foo
		{
			static void nonVirtual();
			this(){nonVirtual();}
		}
	}, sac, true);

	assertAnalyzerWarnings(q{
		class Foo
		{
			package void nonVirtual();
			this(){nonVirtual();}
		}
	}, sac, true);

	assertAnalyzerWarnings(q{
		class C {
			static struct S {
			public:
				this(int) {
					foo();
				}
				void foo() {}
			}
		}
	}, sac, true);

	import std.stdio: writeln;
	writeln("Unittest for VcallCtorChecker passed");
}