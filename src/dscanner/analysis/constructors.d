module dscanner.analysis.constructors;

import std.stdio;
import dscanner.analysis.base;
import dscanner.analysis.helpers;

extern(C++) class ConstructorCheck(AST) : BaseAnalyzerDmd!AST
{
	alias visit = BaseAnalyzerDmd!AST.visit;
	mixin AnalyzerInfo!"constructor_check";

	extern(D) this(string fileName)
	{
		super(fileName);
	}

	override void visit(AST.ClassDeclaration cd)
	{
		immutable bool oldHasDefault = hasDefaultArgConstructor;
		immutable bool oldHasNoArg = hasNoArgConstructor;
		immutable State prev = state;

		hasNoArgConstructor = false;
		hasDefaultArgConstructor = false;
		state = State.inClass;

		super.visit(cd);

		if (hasNoArgConstructor && hasDefaultArgConstructor)
		{
			addErrorMessage(cast(ulong) cd.loc.linnum,
					cast(ulong) cd.loc.charnum, "dscanner.confusing.constructor_args",
					"This class has a zero-argument constructor as well as a"
					~ " constructor with one default argument. This can be confusing.");
		}
		hasDefaultArgConstructor = oldHasDefault;
		hasNoArgConstructor = oldHasNoArg;
		state = prev;
	}

	override void visit(AST.StructDeclaration sd)
	{
		immutable State prev = state;
		
		state = State.inStruct;
		super.visit(sd);
		state = prev;
	}

	override void visit(AST.FuncDeclaration fd)
	{

		auto tf = fd.type.isTypeFunction();

		if (fd.ident.toString() == "__ctor")
		{
			if (tf)
			{

				final switch (state)
				{
				case State.inStruct:
					if (tf.parameterList.parameters.length == 1
							&& (*tf.parameterList.parameters)[0].defaultArg !is null)
					{
						addErrorMessage(cast(ulong) fd.loc.linnum, cast(ulong) fd.loc.charnum,
								"dscanner.confusing.struct_constructor_default_args",
								"This struct constructor can never be called with its "
								~ "default argument.");
					}
					break;
				case State.inClass:
					if (tf.parameterList.parameters.length == 1
							&& (*tf.parameterList.parameters)[0].defaultArg !is null)
					{
						hasDefaultArgConstructor = true;
					}
					else if (tf.parameterList.parameters.length == 0)
						hasNoArgConstructor = true;
					break;
				case State.ignoring:
					break;
				}
			}
		}
		
		super.visit(fd);
	}

private:

	enum State : ubyte
	{
		ignoring,
		inClass,
		inStruct
	}

	State state;

	bool hasNoArgConstructor;
	bool hasDefaultArgConstructor;
}

unittest
{
	import dscanner.analysis.config : StaticAnalysisConfig, Check, disabledConfig;

	StaticAnalysisConfig sac = disabledConfig();
	sac.constructor_check = Check.enabled;
	assertAnalyzerWarningsDMD(q{
		class Cat // [warn]: This class has a zero-argument constructor as well as a constructor with one default argument. This can be confusing.
		{
			this() {}
			this(string name = "kittie") {}
		}

		struct Dog
		{
			this() {}
			this(string name = "doggie") {} // [warn]: This struct constructor can never be called with its default argument.
		}
	}c, sac);

	stderr.writeln("Unittest for ConstructorCheck passed.");
}
