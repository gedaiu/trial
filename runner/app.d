import std.process;
import std.stdio;
import std.algorithm;
import std.getopt;
import std.file;
import std.array;
import std.path;
import std.conv;
import std.string;
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
import dub.packagesupplier;
import dub.platform;
import dub.project;
import dub.description;
import dub.internal.utils;

import trial.generator;
import trial.settings;
import trial.coverage;
import trial.command;
import trial.description;

auto parseGeneralOptions(string[] args) {
	CommonOptions options;

	LogLevel loglevel = LogLevel.info;
	options.root_path = getcwd();

	auto common_args = new CommandArgs(args);
	options.prepare(common_args);

	if (options.vverbose) loglevel = LogLevel.debug_;
	else if (options.verbose) loglevel = LogLevel.diagnostic;
	else if (options.vquiet) loglevel = LogLevel.none;
	else if (options.quiet) loglevel = LogLevel.warn;

	setLogLevel(loglevel);

	return options;
}


private void writeOptions(CommandArgs args)
{
	foreach (arg; args.recognizedArgs) {
		auto names = arg.names.split("|").map!(a => a.length == 1 ? "-" ~ a : "--" ~ a).array;

		writeln("  ", names.join(" "));
		writeln(arg.helpText.map!(a => "     " ~ a).join("\n"));
		writeln;
	}
}

private void showHelp(in TrialCommand command, CommandArgs common_args)
{
	writeln(`USAGE: trial [--version] [subPackage] [<options...>]

Run the tests using the trial runner. It will parse your source files and it will
generate the "generated.d" file. This file contains a custom main function that will
discover and execute your tests.

Available options
==================`);
	writeln();
	writeOptions(common_args);
	writeln();

	showVersion();
}

void showVersion() {
	import trial.version_;
	writefln("Trial %s, based on DUB version %s, built on %s", trialVersion, getDUBVersion(), __DATE__);
}

version(unitttest) {} else {
	int main(string[] arguments) {
		version(Have_arsd_official_terminal) {} else {
			logInfo("\nYou can add `arsd-official:terminal` as a dependency to get coloured output\n");
		}

		version(Windows) {
			environment["TEMP"] = environment["TEMP"].replace("/", "\\");
		}

		arguments = arguments[1..$];

		if(arguments.length > 0 && arguments[0] == "--version") {
			showVersion();
			return 0;
		}

		auto subPackage = arguments.find!(a => a[0] == ':');
		auto subPackageName = subPackage.empty ? "" : subPackage.front;

		auto options = parseGeneralOptions(arguments);
		auto commandArgs = new CommandArgs(arguments);

		auto cmd = new TrialCommand;
		cmd.prepare(commandArgs);

		if (options.help) {
			showHelp(cmd, commandArgs);
			return 0;
		}

		auto dub = createDub(options);
		auto description = new PackageDescriptionCommand(options, subPackageName);

		options = parseGeneralOptions(arguments);

		auto packageName = subPackage.empty ? [] : [ subPackage.front ];

		/// run the trial command
		cmd.setDescription(description);
		auto remainingArgs = commandArgs.extractRemainingArgs();

		if (remainingArgs.any!(a => a.startsWith("-"))) {
			logError("Unknown command line flags: %s", remainingArgs.filter!(a => a.startsWith("-")).array.join(" "));
			return 1;
		}

		try {
			cmd.execute(dub, remainingArgs);
		} catch(Exception e) {
			return 1;
		} finally {
			if(arguments.canFind("--coverage")) {
				writeln("Line coverage: ", convertLstFiles(dub.rootPath.toString, dub.projectName), "%");
			}
		}

		return 0;
	}
}
