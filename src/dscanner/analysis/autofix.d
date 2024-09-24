module dscanner.analysis.autofix;

import std.algorithm : filter, findSplit;
import std.conv : to;
import std.functional : toDelegate;
import std.stdio;

import dparse.lexer;
import dparse.rollback_allocator;
import dparse.ast : Module;

import dsymbol.modulecache : ModuleCache;

import dscanner.analysis.base : AutoFix, AutoFixFormatting, BaseAnalyzer, Message;
import dscanner.analysis.config : StaticAnalysisConfig;
import dscanner.analysis.run : analyze, doNothing;
import dscanner.utils : readFile, readStdin;

private void resolveAutoFixes(
	ref Message message,
	string fileName,
	ref ModuleCache moduleCache,
	scope const(Token)[] tokens,
	const Module m,
	const StaticAnalysisConfig analysisConfig,
	const AutoFixFormatting overrideFormattingConfig = AutoFixFormatting.invalid
)
{
	resolveAutoFixes(message.checkName, message.autofixes, fileName, moduleCache,
		tokens, m, analysisConfig, overrideFormattingConfig);
}

private void resolveAutoFixes(string messageCheckName, AutoFix[] autofixes, string fileName,
	ref ModuleCache moduleCache,
	scope const(Token)[] tokens, const Module m,
	const StaticAnalysisConfig analysisConfig,
	const AutoFixFormatting overrideFormattingConfig = AutoFixFormatting.invalid)
{
	import core.memory : GC;
	import dsymbol.conversion.first : FirstPass;
	import dsymbol.conversion.second : secondPass;
	import dsymbol.scope_ : Scope;
	import dsymbol.semantic : SemanticSymbol;
	import dsymbol.string_interning : internString;
	import dsymbol.symbol : DSymbol;
	import dscanner.analysis.run : getAnalyzersForModuleAndConfig;

	const(AutoFixFormatting) formattingConfig =
	overrideFormattingConfig is AutoFixFormatting.invalid
	? analysisConfig.getAutoFixFormattingConfig()
	: overrideFormattingConfig;

	scope first = new FirstPass(m, internString(fileName), &moduleCache, null);
	first.run();

	secondPass(first.rootSymbol, first.moduleScope, moduleCache);
	auto moduleScope = first.moduleScope;
	scope(exit) typeid(DSymbol).destroy(first.rootSymbol.acSymbol);
	scope(exit) typeid(SemanticSymbol).destroy(first.rootSymbol);
	scope(exit) typeid(Scope).destroy(first.moduleScope);

	GC.disable;
	scope (exit)
	GC.enable;

	foreach (BaseAnalyzer check; getAnalyzersForModuleAndConfig(fileName, tokens, m, analysisConfig, moduleScope))
	{
		if (check.getName() == messageCheckName)
		{
			foreach (ref autofix; autofixes)
				autofix.resolveAutoFixFromCheck(check, m, tokens, formattingConfig);
			return;
		}
	}

	throw new Exception("Cannot find analyzer " ~ messageCheckName
	~ " to resolve autofix with.");
}

///
void resolveAutoFixFromCheck(
	ref AutoFix autofix,
	BaseAnalyzer check,
	const Module m,
	scope const(Token)[] tokens,
	const AutoFixFormatting formattingConfig
)
{
	import std.sumtype : match;

	autofix.replacements.match!(
			(AutoFix.ResolveContext context) {
			autofix.replacements = check.resolveAutoFix(m, tokens, context, formattingConfig);
		},
			(_) {}
	);
}

private AutoFix.CodeReplacement[] resolveAutoFix(string messageCheckName, AutoFix.ResolveContext context,
	string fileName,
	ref ModuleCache moduleCache,
	scope const(Token)[] tokens, const Module m,
	const StaticAnalysisConfig analysisConfig,
	const AutoFixFormatting overrideFormattingConfig = AutoFixFormatting.invalid)
{
	AutoFix temp;
	temp.replacements = context;
	resolveAutoFixes(messageCheckName, (&temp)[0 .. 1], fileName, moduleCache,
	tokens, m, analysisConfig, overrideFormattingConfig);
	return temp.expectReplacements("resolving didn't work?!");
}

///
void listAutofixes(
	StaticAnalysisConfig config,
	string resolveMessage,
	bool usingStdin,
	string fileName,
	StringCache* cache,
	ref ModuleCache moduleCache
)
{
	import dparse.parser : parseModule;
	import dscanner.analysis.base : Message;
	import std.format : format;
	import std.json : JSONValue;

	union RequestedLocation
	{
		struct
		{
			uint line, column;
		}
		ulong bytes;
	}

	RequestedLocation req;
	bool isBytes = resolveMessage[0] == 'b';
	if (isBytes)
		req.bytes = resolveMessage[1 .. $].to!ulong;
	else
	{
		auto parts = resolveMessage.findSplit(":");
		req.line = parts[0].to!uint;
		req.column = parts[2].to!uint;
	}

	bool matchesCursor(Message m)
	{
		return isBytes
		? req.bytes >= m.startIndex && req.bytes <= m.endIndex
		: req.line >= m.startLine && req.line <= m.endLine
		&& (req.line > m.startLine || req.column >= m.startColumn)
		&& (req.line < m.endLine || req.column <= m.endColumn);
	}

	RollbackAllocator rba;
	LexerConfig lexerConfig;
	lexerConfig.fileName = fileName;
	lexerConfig.stringBehavior = StringBehavior.source;
	auto tokens = getTokensForParser(usingStdin ? readStdin()
	: readFile(fileName), lexerConfig, cache);
	auto mod = parseModule(tokens, fileName, &rba, toDelegate(&doNothing));

	auto messages = analyze(fileName, mod, config, moduleCache, tokens);

	with (stdout.lockingTextWriter)
	{
		put("[");
		foreach (message; messages[].filter!matchesCursor)
		{
			resolveAutoFixes(message, fileName, moduleCache, tokens, mod, config);

			foreach (i, autofix; message.autofixes)
			{
				put(i == 0 ? "\n" : ",\n");
				put("\t{\n");
				put(format!"\t\t\"name\": %s,\n"(JSONValue(autofix.name)));
				put("\t\t\"replacements\": [");
				foreach (j, replacement; autofix.expectReplacements)
				{
					put(j == 0 ? "\n" : ",\n");
					put(format!"\t\t\t{\"range\": [%d, %d], \"newText\": %s}"(
						replacement.range[0],
						replacement.range[1],
						JSONValue(replacement.newText)));
				}
				put("\n");
				put("\t\t]\n");
				put("\t}");
			}
		}
		put("\n]");
	}
	stdout.flush();
}
