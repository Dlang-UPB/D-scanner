//          Copyright Basile Burg 2017.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//
module dscanner.analysis.vcall_in_ctor;

import dscanner.analysis.base;
import dscanner.utils;

/**
 * Checks virtual calls from the constructor to methods defined in the same class.
 *
 * When not used carefully, virtual calls from constructors can lead to a call
 * in a derived instance that's not yet constructed.
 */
extern (C++) class VcallCtorChecker(AST) : BaseAnalyzerDmd
{
	alias visit = BaseAnalyzerDmd.visit;
	mixin AnalyzerInfo!"vcall_in_ctor";

	private int ctorLevel;
	private enum MSG = "a virtual call inside a constructor may lead to unexpected results in the derived classes";
	private enum string KEY = "dscanner.vcall_ctor";

	extern (D) this(string fileName, bool skipTests = false)
	{
		super(fileName, skipTests);
	}

	override void visit(AST.ClassDeclaration classDecl)
	{
		if (classDecl.members)
		{
			foreach (member; *classDecl.members)
			{
				if (member.isCtorDeclaration())
				{
					ctorLevel++;
					member.accept(this);
					ctorLevel--;
				}
			}
		}
	}

	override void visit(AST.CallExp callExpr)
	{
		if (ctorLevel >= 0 && isVirtualMethod(callExpr))
			addErrorMessage(cast(ulong) callExpr.loc.linnum, cast(ulong) callExpr.loc.charnum, KEY, MSG);
	}

	private bool isVirtualMethod(AST.CallExp callExpr)
	{
		return callExpr.f && callExpr.f.isVirtualMethod();
	}
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dscanner.analysis.helpers : assertAnalyzerWarningsDMD;
	import std.stdio : stderr;
	import std.format : format;

	StaticAnalysisConfig sac = disabledConfig();
	sac.vcall_in_ctor = Check.enabled;

	enum MSG = "a virtual call inside a constructor may lead to unexpected results in the derived classes";

	// fails
	assertAnalyzerWarningsDMD(q{
		class Bar
		{
			this() { foo(); } // [warn]: %s
			private:
			public
			void foo() {}
		}
	}c.format(MSG), sac, true);

	assertAnalyzerWarningsDMD(q{
		class Bar
		{
			this()
			{
				foo(); // [warn]: %s
				foo(); // [warn]: %s
				bar();
			}
			private: void bar();
			public { void foo() {} }
		}
	}c.format(MSG, MSG), sac, true);

	assertAnalyzerWarningsDMD(q{
		class Foo
		{
			this()
			{
				class Bar
				{
					this() { bar(); }
					private void bar();
				}

				foo(); // [warn]: %s
			}

			void foo() {}
		}
	}c.format(MSG), sac, true);

	// passes

	assertAnalyzerWarningsDMD(q{
		class D
		{
			this(int a)
			{
				class T
				{
					void bar() {}
					void foobar () {  bar(); }
				}
			}
		}
	}c, sac, true);

	assertAnalyzerWarningsDMD(q{
		class Bar
		{
			this() { foo(); }
			private void foo() {}
		}
	}c, sac, true);

	assertAnalyzerWarningsDMD(q{
		class Bar
		{
			this() { foo(); }
			private { void foo() {} }
		}
	}c, sac, true);

	assertAnalyzerWarningsDMD(q{
		interface I
		{
			final void foo() {}
		}

		class C : I
		{
			this() { foo(); }
		}
	}c, sac, true);

	assertAnalyzerWarningsDMD(q{
		final class Bar
		{
			public:
			this() { foo(); }
			void foo() {}
		}
	}c, sac, true);

	assertAnalyzerWarningsDMD(q{
		class Bar
		{
			public:
			this() { foo!int(); }
			void foo(T)() {}
		}
	}c, sac, true);

	assertAnalyzerWarningsDMD(q{
		class Foo
		{
			static void nonVirtual();
			this() { nonVirtual(); }
		}
	}c, sac, true);

	assertAnalyzerWarningsDMD(q{
		class Foo
		{
			package void nonVirtual();
			this() { nonVirtual(); }
		}
	}c, sac, true);

	assertAnalyzerWarningsDMD(q{
		class C {
			static struct S {
			public:
				this(int) {
					foo();
				}
				void foo() {}
			}
		}
	}c, sac, true);

	stderr.writeln("Unittest for VcallCtorChecker passed");
}
