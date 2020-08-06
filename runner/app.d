import std.process;
import std.stdio;
import std.algorithm;
import std.getopt;
import std.file;
import std.array;
import std.path;
import std.conv;
import std.string;
import std.encoding : sanitize;
import core.time;
import core.thread;

import dub.internal.vibecompat.data.json;

import dub.commandline;
import dub.compilers.compiler;
import dub.dependency;
import dub.dub;
import dub.generators.generator;
import dub.internal.vibecompat.core.file;
import dub.internal.vibecompat.core.log;
import dub.internal.vibecompat.data.json;
import dub.internal.vibecompat.inet.url;
import dub.package_;
import dub.packagemanager;
import dub.packagesuppliers;
import dub.platform;
import dub.project;
import dub.description;
import dub.internal.utils;

import trial.generator;
import trial.settings;
import trial.coverage;
import trial.command;
import trial.runnersettings;

auto parseGeneralOptions(string[] args, bool isSilent) {
  CommonOptions options;

  LogLevel loglevel = LogLevel.info;
  options.root_path = getcwd();

  auto common_args = new CommandArgs(args);
  options.prepare(common_args);

  if (options.vverbose) loglevel = LogLevel.debug_;
  else if (options.verbose) loglevel = LogLevel.diagnostic;
  else if (options.vquiet) loglevel = LogLevel.none;
  else if (options.quiet) loglevel = LogLevel.warn;

  setLogLevel(isSilent ? LogLevel.none : loglevel);

  return options;
}



/** Retrieves a list of all available commands.

	Commands are grouped by category.
*/
CommandGroup[] getCommands(RunnerSettings runnerSettings)
{
	return [
		CommandGroup("Build, test and run",
			new TrialRunCommand(runnerSettings),
      new TrialDescribeCommand(runnerSettings),
      new TrialSubpackagesCommand(runnerSettings)
		)
	];
}

private {
	enum shortArgColumn = 2;
	enum longArgColumn = 6;
	enum descColumn = 24;
	enum lineWidth = 80 - 1;
}

private void showHelp(in CommandGroup[] commands, CommandArgs common_args)
{
	writeln(
`USAGE: trial [--version] [<command>] [<options...>]

Run the tests using the trial runner. It will parse your source files and it will
generate the "trial_package.d" file. This file contains a custom main function that will
discover and execute your tests.


Available commands
==================`);

	foreach (grp; commands) {
		writeln();
		writeWS(shortArgColumn);
		writeln(grp.caption);
		writeWS(shortArgColumn);
		writerep!'-'(grp.caption.length);
		writeln();
		foreach (cmd; grp.commands) {
			if (cmd.hidden) continue;
			writeWS(shortArgColumn);
			writef("%s %s", cmd.name, cmd.argumentsPattern);
			auto chars_output = cmd.name.length + cmd.argumentsPattern.length + shortArgColumn + 1;
			if (chars_output < descColumn) {
				writeWS(descColumn - chars_output);
			} else {
				writeln();
				writeWS(descColumn);
			}
			writeWrapped(cmd.description, descColumn, descColumn);
		}
	}
	writeln();
	writeln();
	writeln(`Common options`);
	writeln(`==============`);
	writeln();
	writeOptions(common_args);
	writeln();
	showVersion();
}


private void writeOptions(CommandArgs args)
{
	foreach (arg; args.recognizedArgs) {
		auto names = arg.names.split("|");
		assert(names.length == 1 || names.length == 2);
		string sarg = names[0].length == 1 ? names[0] : null;
		string larg = names[0].length > 1 ? names[0] : names.length > 1 ? names[1] : null;
		if (sarg !is null) {
			writeWS(shortArgColumn);
			writef("-%s", sarg);
			writeWS(longArgColumn - shortArgColumn - 2);
		} else writeWS(longArgColumn);
		size_t col = longArgColumn;
		if (larg !is null) {
			if (arg.defaultValue.peek!bool) {
				writef("--%s", larg);
				col += larg.length + 2;
			} else {
				writef("--%s=VALUE", larg);
				col += larg.length + 8;
			}
		}
		if (col < descColumn) {
			writeWS(descColumn - col);
		} else {
			writeln();
			writeWS(descColumn);
		}
		foreach (i, ln; arg.helpText) {
			if (i > 0) writeWS(descColumn);
			ln.writeWrapped(descColumn, descColumn);
		}
	}
}

private void writeWrapped(string string, size_t indent = 0, size_t first_line_pos = 0)
{
	// handle pre-indented strings and bullet lists
	size_t first_line_indent = 0;
	while (string.startsWith(" ")) {
		string = string[1 .. $];
		indent++;
		first_line_indent++;
	}
	if (string.startsWith("- ")) indent += 2;

	auto wrapped = string.wrap(lineWidth, getRepString!' '(first_line_pos+first_line_indent), getRepString!' '(indent));
	wrapped = wrapped[first_line_pos .. $];
	foreach (ln; wrapped.splitLines())
		writeln(ln);
}

private void writeWS(size_t num) { writerep!' '(num); }
private void writerep(char ch)(size_t num) { write(getRepString!ch(num)); }

private string getRepString(char ch)(size_t len)
{
	static string buf;
	if (len > buf.length) buf ~= [ch].replicate(len-buf.length);
	return buf[0 .. len];
}

private void showCommandHelp(Command cmd, CommandArgs args, CommandArgs common_args)
{
	writefln(`USAGE: dub %s %s [<options...>]%s`, cmd.name, cmd.argumentsPattern, cmd.acceptsAppArgs ? " [-- <application arguments...>]": null);
	writeln();
	foreach (ln; cmd.helpText)
		ln.writeWrapped();

	if (args.recognizedArgs.length) {
		writeln();
		writeln();
		writeln("Command specific options");
		writeln("========================");
		writeln();
		writeOptions(args);
	}

	writeln();
	writeln();
	writeln("Common options");
	writeln("==============");
	writeln();
	writeOptions(common_args);
	writeln();
	writefln("DUB version %s, built on %s", getDUBVersion(), __DATE__);
}

void showVersion() {
  import trial.version_;
  writefln("Trial %s, based on DUB version %s, built on %s", trialVersion, getDUBVersion(), __DATE__);
}

version(unitttest) {} else {
  int main(string[] args) {
    import trial.runner;
    setupSegmentationHandler!false;

    args = args.map!(a => a.strip).filter!(a => a != "").array;

    version(Windows) {
      environment["TEMP"] = environment["TEMP"].replace("/", "\\");
    }

		auto common_args = new CommandArgs(args[1..$]);

		auto runnerSettings = new RunnerSettings;
		runnerSettings.applyArguments(common_args);

		auto handler = CommandLineHandler(getCommands(runnerSettings));

		try handler.prepareOptions(common_args);
		catch (Throwable e) {
			logError("Error processing arguments: %s", e.msg);
			logDiagnostic("Full exception: %s", e.toString().sanitize);
			logInfo("Run 'dub help' for usage information.");
			return 1;
		}

		if (handler.options.version_)
		{
			showVersion();
			return 0;
		}

		// extract the command
		args = common_args.extractAllRemainingArgs();

		auto command_name_argument = extractCommandNameArgument(args);

		auto command_args = new CommandArgs(command_name_argument.remaining);
		Command cmd;

		try {
			cmd = handler.prepareCommand(command_name_argument.value, command_args);
		} catch (Throwable e) {
			logError("Error processing arguments: %s", e.msg);
			logDiagnostic("Full exception: %s", e.toString().sanitize);
			logInfo("Run 'dub help' for usage information.");
			return 1;
		}

		if (cmd is null) {
			logError("Unknown command: %s", command_name_argument.value);
			writeln();
			showHelp(handler.commandGroups, common_args);
			return 1;
		}

		if (cmd.name == "help") {
			showHelp(handler.commandGroups, common_args);
			return 0;
		}

		if (handler.options.help) {
			showCommandHelp(cmd, command_args, common_args);
			return 0;
		}

		auto remaining_args = command_args.extractRemainingArgs();
		if (remaining_args.any!(a => a.startsWith("-"))) {
			logError("Unknown command line flags: %s", remaining_args.filter!(a => a.startsWith("-")).array.join(" "));
			logError(`Type "dub %s -h" to get a list of all supported flags.`, cmd.name);
			return 1;
		}

		Dub dub;

		// initialize the root package
		if (!cmd.skipDubInitialization) {
			dub = handler.prepareDub;
		}

		// execute the command
		try return cmd.execute(dub, remaining_args, command_args.appArgs);
		catch (Exception e) {
			logError("%s", e.msg);
			logDebug("Full exception: %s", e.toString().sanitize);
			logInfo(`Run "dub %s -h" for more information about the "%s" command.`, cmd.name, cmd.name);
			return 1;
		}
		catch (Throwable e) {
			logError("%s", e.msg);
			logDebug("Full exception: %s", e.toString().sanitize);
			return 2;
		}
  }
}
