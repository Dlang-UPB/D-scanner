//          Copyright Basile Burg 2017.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.final_attribute;

import dscanner.analysis.base;
import dscanner.analysis.helpers;
import std.string : format;
import std.stdio;

/**
 * Checks for useless usage of the final attribute.
 *
 * There are several cases where the compiler allows them even if it's a noop.
 */
extern(C++) class FinalAttributeChecker(AST) : BaseAnalyzerDmd!AST
{

	mixin AnalyzerInfo!"final_attribute_check";
	alias visit = BaseAnalyzerDmd!AST.visit;

	enum Parent
	{
		module_,
		struct_,
		union_,
		class_,
		function_,
		interface_
	}

	bool _private;
	bool _inFinalClass;
	bool _alwaysStatic;
	bool _blockStatic;
	bool _blockFinal;
	Parent _parent = Parent.module_;

	enum pushPopPrivate = q{
		const bool wasPrivate = _private;
		_private = false;
		scope (exit) _private = wasPrivate;
	};

	extern(D) this(string fileName)
	{
		super(fileName);
	}

	override void visit(AST.StorageClassDeclaration scd)
	{
		import dmd.astenums : STC;

		if (scd.stc & STC.static_)
			_blockStatic = true;

		if (scd.stc & STC.final_)
			_blockFinal = true;

		if (!scd.decl)
			return;

		foreach (member; *scd.decl)
		{
			auto sd = member.isStructDeclaration();
			auto ud = member.isUnionDeclaration();

			if (!ud && sd && scd.stc & STC.final_)
			{
				addErrorMessage(cast(ulong) sd.loc.linnum, cast(ulong) sd.loc.charnum, KEY,
					MSGB.format(FinalAttributeChecker.MESSAGE.struct_i));
			}

			if (ud && scd.stc & STC.final_)
			{
				addErrorMessage(cast(ulong) ud.loc.linnum, cast(ulong) ud.loc.charnum, KEY,
					MSGB.format(FinalAttributeChecker.MESSAGE.union_i));
			}

			member.accept(this);
		}
	}

	override void visit(AST.TemplateDeclaration td)
	{
		import dmd.astenums : STC;
		import dmd.astbase;

		if (!td.members)
			return;

		foreach (member; *td.members)
        {
			auto fd = member.isFuncDeclaration();

			if (fd)
			{
				if (_parent == Parent.class_ && fd.storage_class & STC.final_)
					addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
						MSGB.format(FinalAttributeChecker.MESSAGE.class_t));

				if (_parent == Parent.interface_ && fd.storage_class & STC.final_)
					addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
						MSGB.format(FinalAttributeChecker.MESSAGE.interface_t));
			}
		}

	}

	override void visit(AST.ClassDeclaration cd)
	{
		if (_blockFinal && !_inFinalClass)
			_inFinalClass = true;
		else if (_inFinalClass)
			_inFinalClass = false;

		mixin (pushPopPrivate);
		const Parent saved = _parent;
		_parent = Parent.class_;
		super.visit(cd);
		_parent = saved;
		_inFinalClass = false;
	}

	override void visit(AST.FuncDeclaration fd)
	{
		import dmd.astenums : STC;
	
		if (_parent == Parent.class_ && _private && fd.storage_class & STC.final_)
			addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
				MSGB.format(FinalAttributeChecker.MESSAGE.class_p));

		else if (fd.storage_class & STC.final_ && (fd.storage_class & STC.static_ || _blockStatic))
			addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
				MSGB.format(FinalAttributeChecker.MESSAGE.class_s));

		else if (_parent == Parent.class_ && _inFinalClass && fd.storage_class & STC.final_)
			addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
				MSGB.format(FinalAttributeChecker.MESSAGE.class_f));

		if (_parent == Parent.struct_ && fd.storage_class & STC.final_)
			addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
				MSGB.format(FinalAttributeChecker.MESSAGE.struct_f));

		if (_parent == Parent.union_ && fd.storage_class & STC.final_)
			addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
				MSGB.format(FinalAttributeChecker.MESSAGE.union_f));

		if (_parent == Parent.module_ && fd.storage_class & STC.final_)
			addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
				MSGB.format(FinalAttributeChecker.MESSAGE.func_g));

		if (_parent == Parent.function_ && fd.storage_class & STC.final_)
			addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum, KEY,
				MSGB.format(FinalAttributeChecker.MESSAGE.func_n));

		mixin (pushPopPrivate);
		const Parent saved = _parent;
		_parent = Parent.function_;
		super.visit(fd);
		_parent = saved;
	}

	override void visit(AST.InterfaceDeclaration id)
	{
		mixin (pushPopPrivate);
		const Parent saved = _parent;
		_parent = Parent.interface_;
		super.visit(id);
		_parent = saved;
	}

	override void visit(AST.UnionDeclaration ud)
	{
		mixin (pushPopPrivate);
		const Parent saved = _parent;
		_parent = Parent.union_;
		super.visit(ud);
		_parent = saved;
	}

	override void visit(AST.StructDeclaration sd)
	{
		mixin (pushPopPrivate);
		const Parent saved = _parent;
		_parent = Parent.struct_;
		super.visit(sd);
		_parent = saved;
	}

	override void visit(AST.VisibilityDeclaration vd)
	{
		import dmd.astbase;

		if (vd.visibility.kind == ASTBase.Visibility.Kind.private_)
			_private = true;
		else
			_private = false;
		
		super.visit(vd);
			_private = false;
	}

	enum KEY = "dscanner.useless.final";
	enum string MSGB = "Useless final attribute, %s";
	extern(D) static struct MESSAGE
	{
		static immutable struct_i    = "structs cannot be subclassed";
		static immutable union_i     = "unions cannot be subclassed";
		static immutable class_t     = "templated functions declared within a class are never virtual";
		static immutable class_p     = "private functions declared within a class are never virtual";
		static immutable class_f     = "functions declared within a final class are never virtual";
		static immutable class_s     = "static functions are never virtual";
		static immutable interface_t = "templated functions declared within an interface are never virtual";
		static immutable struct_f    = "functions declared within a struct are never virtual";
		static immutable union_f     = "functions declared within an union are never virtual";
		static immutable func_n      = "nested functions are never virtual";
		static immutable func_g      = "global functions are never virtual";
	}
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;
	import dmd.astbase;

	StaticAnalysisConfig sac = disabledConfig();
	sac.final_attribute_check = Check.enabled;
	
	assertAnalyzerWarningsDMD(q{
		void foo(){}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		void foo(){void foo(){}}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		struct S{}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		union U{}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		class Foo{public final void foo(){}}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		final class Foo{static struct Bar{}}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		class Foo{private: public final void foo(){}}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		class Foo{private: public: final void foo(){}}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		class Foo{private: public: final void foo(){}}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		class Impl
		{
			private:
			static if (true)
			{
				protected final void _wrap_getSource() {}
			}
		}
	}, sac);

	assertAnalyzerWarningsDMD(q{
		mixin template Impl()
		{
			protected final void mixin_template_can() {}
		}
	}, sac);

	// fail

	assertAnalyzerWarningsDMD(q{
		final void foo(){} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.func_g)
	), sac);

	assertAnalyzerWarningsDMD(q{
		void foo(){final void foo(){}} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.func_n)
	), sac);

	assertAnalyzerWarningsDMD(q{
		void foo()
		{
			static if (true)
			final class A{ private: final protected void foo(){}} // [warn]: %s
		}
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.class_f)
	), sac);

	assertAnalyzerWarningsDMD(q{
		final struct Foo{} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.struct_i)
	), sac);

	assertAnalyzerWarningsDMD(q{
		final union Foo{} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.union_i)
	), sac);

	assertAnalyzerWarningsDMD(q{
		class Foo{private final void foo(){}} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.class_p)
	), sac);

	assertAnalyzerWarningsDMD(q{
		class Foo{private: final void foo(){}} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.class_p)
	), sac);

	assertAnalyzerWarningsDMD(q{
		interface Foo{final void foo(T)(){}} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.interface_t)
	), sac);

	assertAnalyzerWarningsDMD(q{
		final class Foo{final void foo(){}} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.class_f)
	), sac);

	assertAnalyzerWarningsDMD(q{
		private: final class Foo {public: private final void foo(){}} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.class_p)
	), sac);

	assertAnalyzerWarningsDMD(q{
		class Foo {final static void foo(){}} // [warn]: %s
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.class_s)
	), sac);

	assertAnalyzerWarningsDMD(q{
		class Foo
		{
			void foo(){}
			static: final void foo(){} // [warn]: %s
		}
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.class_s)
	), sac);

	assertAnalyzerWarningsDMD(q{
		class Foo
		{
			void foo(){}
			static{ final void foo(){}} // [warn]: %s
			void foo(){}
		}
	}c.format(
		(FinalAttributeChecker!ASTBase).MSGB.format((FinalAttributeChecker!ASTBase).MESSAGE.class_s)
	), sac);


	assertAnalyzerWarningsDMD(q{
		class Statement
		{
			final class UsesEH{}
			final void comeFrom(){}
		}
	}, sac);

	stderr.writeln("Unittest for FinalAttributeChecker passed.");
}
