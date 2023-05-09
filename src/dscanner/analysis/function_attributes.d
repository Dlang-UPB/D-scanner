//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dscanner.analysis.function_attributes;

import dscanner.analysis.base;
import dparse.ast;
import dparse.lexer;
import std.stdio;
import dsymbol.scope_;

/**
 * Prefer
 * ---
 * int getStuff() const {}
 * ---
 * to
 * ---
 * const int getStuff() {}
 * ---
 */
final class FunctionAttributeCheck : BaseAnalyzer
{
	alias visit = BaseAnalyzer.visit;

	mixin AnalyzerInfo!"function_attribute_check";

	this(string fileName, const(Scope)* sc, bool skipTests = false)
	{
		super(fileName, sc, skipTests);
	}

	override void visit(const InterfaceDeclaration dec)
	{
		const t = inInterface;
		const t2 = inAggregate;
		inInterface = true;
		inAggregate = true;
		dec.accept(this);
		inInterface = t;
		inAggregate = t2;
	}

	override void visit(const ClassDeclaration dec)
	{
		const t = inInterface;
		const t2 = inAggregate;
		inInterface = false;
		inAggregate = true;
		dec.accept(this);
		inInterface = t;
		inAggregate = t2;
	}

	override void visit(const StructDeclaration dec)
	{
		const t = inInterface;
		const t2 = inAggregate;
		inInterface = false;
		inAggregate = true;
		dec.accept(this);
		inInterface = t;
		inAggregate = t2;
	}

	override void visit(const UnionDeclaration dec)
	{
		const t = inInterface;
		const t2 = inAggregate;
		inInterface = false;
		inAggregate = true;
		dec.accept(this);
		inInterface = t;
		inAggregate = t2;
	}

	override void visit(const AttributeDeclaration dec)
	{
		if (inInterface && dec.attribute.attribute == tok!"abstract")
		{
			addErrorMessage(dec.attribute.attribute.line,
					dec.attribute.attribute.column, KEY, ABSTRACT_MESSAGE);
		}
	}

	override void visit(const FunctionDeclaration dec)
	{
		if (dec.parameters.parameters.length == 0 && inAggregate)
		{
			bool foundConst;
			bool foundProperty;
			foreach (attribute; dec.attributes)
				foundConst = foundConst || attribute.attribute.type == tok!"const"
					|| attribute.attribute.type == tok!"immutable"
					|| attribute.attribute.type == tok!"inout";
			foreach (attribute; dec.memberFunctionAttributes)
			{
				foundProperty = foundProperty || (attribute.atAttribute !is null
						&& attribute.atAttribute.identifier.text == "property");
				foundConst = foundConst || attribute.tokenType == tok!"const"
					|| attribute.tokenType == tok!"immutable" || attribute.tokenType == tok!"inout";
			}
			if (foundProperty && !foundConst)
			{
				addErrorMessage(dec.name.line, dec.name.column, KEY,
						"Zero-parameter '@property' function should be"
						~ " marked 'const', 'inout', or 'immutable'.");
			}
		}
		dec.accept(this);
	}

	override void visit(const Declaration dec)
	{
		if (dec.attributes.length == 0)
			goto end;
		foreach (attr; dec.attributes)
		{
			if (attr.attribute.type == tok!"")
				continue;
			if (attr.attribute == tok!"abstract" && inInterface)
			{
				addErrorMessage(attr.attribute.line, attr.attribute.column, KEY, ABSTRACT_MESSAGE);
				continue;
			}
			if (dec.functionDeclaration !is null && (attr.attribute == tok!"const"
					|| attr.attribute == tok!"inout" || attr.attribute == tok!"immutable"))
			{
				import std.string : format;

				immutable string attrString = str(attr.attribute.type);
				addErrorMessage(dec.functionDeclaration.name.line,
						dec.functionDeclaration.name.column, KEY, format(
							"'%s' is not an attribute of the return type." ~ " Place it after the parameter list to clarify.",
							attrString));
			}
		}
	end:
		dec.accept(this);
	}

private:
	bool inInterface;
	bool inAggregate;
	enum string ABSTRACT_MESSAGE = "'abstract' attribute is redundant in interface declarations";
	enum string KEY = "dscanner.confusing.function_attributes";
}
