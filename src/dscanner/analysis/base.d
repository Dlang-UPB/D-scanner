module dscanner.analysis.base;

import std.container;
import std.string;
import dparse.ast;
import std.array;
import dsymbol.scope_ : Scope;
import dmd.transitivevisitor;
import core.stdc.string;
import std.conv : to;

struct Message
{
	/// Name of the file where the warning was triggered
	string fileName;
	/// Line number where the warning was triggered
	size_t line;
	/// Column number where the warning was triggered (in bytes)
	size_t column;
	/// Name of the warning
	string key;
	/// Warning message
	string message;
	/// Check name
	string checkName;
}

enum comparitor = q{ a.line < b.line || (a.line == b.line && a.column < b.column) };

alias MessageSet = RedBlackTree!(Message, comparitor, true);

/** 
 * Should be present in all visitors to specify the name of the check
 *  done by a patricular visitor
 */
mixin template AnalyzerInfo(string checkName)
{
	enum string name = checkName;

	extern(D) override protected string getName()
	{
		return name;
	}
}

abstract class BaseAnalyzer : ASTVisitor
{
public:
	this(string fileName, const Scope* sc, bool skipTests = false)
	{
		this.sc = sc;
		this.fileName = fileName;
		this.skipTests = skipTests;
		_messages = new MessageSet;
	}

	protected string getName()
	{
		assert(0);
	}

	Message[] messages()
	{
		return _messages[].array;
	}

	alias visit = ASTVisitor.visit;

	/**
	* Visits a unittest.
	*
	* When overriden, the protected bool "skipTests" should be handled
	* so that the content of the test is not analyzed.
	*/
	override void visit(const Unittest unittest_)
	{
		if (!skipTests)
			unittest_.accept(this);
	}

protected:

	bool inAggregate;
	bool skipTests;

	template visitTemplate(T)
	{
		override void visit(const T structDec)
		{
			inAggregate = true;
			structDec.accept(this);
			inAggregate = false;
		}
	}

	void addErrorMessage(size_t line, size_t column, string key, string message)
	{
		_messages.insert(Message(fileName, line, column, key, message, getName()));
	}

	/**
	 * The file name
	 */
	string fileName;

	const(Scope)* sc;

	MessageSet _messages;
}

/** 
 * Visitor that implements the AST traversal logic.
 * Supports collecting error messages
 */
extern(C++) class BaseAnalyzerDmd(AST) : ParseTimeTransitiveVisitor!AST
{
	alias visit = ParseTimeTransitiveVisitor!AST.visit;

	extern(D) this(string fileName, bool skipTests = false)
	{
		this.fileName = fileName;
		this.skipTests = skipTests;
		_messages = new MessageSet;
	}

	/** 
	 * Ensures that template AnalyzerInfo is instantiated in all classes
	 *  deriving from this class 
	 */
	extern(D) protected string getName()
	{
		assert(0);
	}

	extern(D) Message[] messages()
	{
		return _messages[].array;
	}

	override void visit(AST.UnitTestDeclaration ud)
	{
		if (!skipTests)
			super.visit(ud);
	}


protected:

	extern(D) void addErrorMessage(size_t line, size_t column, string key, string message)
	{
		_messages.insert(Message(fileName, line, column, key, message, getName()));
	}

	extern(D) bool skipTests;

	/**
	 * The file name
	 */
	extern(D) string fileName;

	extern(D) MessageSet _messages;
}
