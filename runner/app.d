import std.process;
import std.stdio;
import std.algorithm;
import std.getopt;
import std.file;
import std.array;
import std.conv;
import core.time;
import core.thread;
import vibe.data.json;

import trial.generator;
import trial.settings;

int runTests(string[] arguments, string path) {
	auto cmd = ["dub", "test"] ~ arguments[1..$] ~ ["--main-file=generated.d"];

	auto pid = spawnProcess(cmd, std.stdio.stdin, std.stdio.stdout, std.stdio.stderr, null, Config.none, path);
	scope(exit) wait(pid);

	bool running = true;
	int status;

	while(running) {
		auto dub = tryWait(pid);

		running = !dub.terminated;

		if(dub.terminated) {
			status = dub.status;
		}
	}

	return status;
}

Json dubDescribe(string path, string subPackage) {
	auto cmd = ["dub", "describe", subPackage];

	if(path != ".") {
		cmd ~= [ "--root=" ~ path ];
	}

	auto pipes = pipeProcess(cmd, Redirect.stdout | Redirect.stderr);
	scope(exit) wait(pipes.pid);

	bool running = true;
	int status;
	string data;

	while(running) {
		auto dub = tryWait(pipes.pid);

		running = !dub.terminated;

		if(dub.terminated) {
			status = dub.status;
		}

		pipes.stdout.byLine.each!(a => data ~= a);
		Thread.sleep(10.msecs);
	}

	try {
		Json describe = data.parseJsonString;

		return describe;
	} catch(Exception e) {
		data.writeln("\n\n");

		throw e;
	}
}

string[] findModules(Json describe, string subPackage) {
	string rootPackage = describe["rootPackage"].to!string;

	writeln("Looking for files inside `", rootPackage,"`");

	auto neededPackage = (cast(Json[]) describe["targets"])
		.filter!(a => a["rootPackage"].to!string.canFind(rootPackage))
		.filter!(a => a["rootPackage"].to!string.canFind(subPackage));

	if(neededPackage.empty) {
		return [];
	}

	return (cast(Json[]) neededPackage.front["buildSettings"]["sourceFiles"])
		.map!(a => a.to!string)
		.map!(a => getModuleName(a))
		.filter!(a => a != "")
			.array;
}

string[] findExternalModules(Json describe) {
	string rootPackage = describe["rootPackage"].to!string;

	auto neededPackages = (cast(Json[]) describe["targets"])
		.filter!(a => !a["rootPackage"].to!string.canFind(rootPackage));

	if(neededPackages.empty) {
		return [];
	}

	Json[] files = cast(Json[])reduce!((a, b) => a ~ b)(Json.emptyArray, neededPackages.map!(a => a["buildSettings"]["sourceFiles"]));

	return files
		.map!(a => a.to!string)
		.map!(a => getModuleName(a))
		.filter!(a => a != "")
			.array;
}

string getModuleName(string fileName) {
	auto file = File(fileName);

	auto moduleLine = file.byLine()
		.map!(a => a.to!string)
		.filter!(a => a.startsWith("module"));

	if(moduleLine.empty) {
		return "";
	}

	return moduleLine.front.split(' ')[1].split(";")[0];
}

bool hasTrial(Json describe, string subPackage) {
	string rootPackage = describe["rootPackage"].to!string;

	auto neededPackage = (cast(Json[]) describe["targets"])
		.filter!(a => a["rootPackage"].to!string.canFind(rootPackage))
		.filter!(a => a["rootPackage"].to!string.canFind(subPackage));

		if(neededPackage.empty) {
			return false;
		}

		Json[] versions = (cast(Json[]) neededPackage.front["buildSettings"]["versions"]);
		auto hasVersion = versions
			.map!(a => a.to!string)
			.filter!(a => a == "Have_trial_lifecycle").empty;

		return !hasVersion;
}

Settings readSettings(string root) {
	if(!"trial.json".exists) {
		Settings def;
		std.file.write(root ~ "/trial.json", def.serializeToJson.toPrettyString);
	}

	Settings settings = readText(root ~ "/trial.json").deserializeJson!Settings;

	return settings;
}

version(unitttest) {} else {
	int main(string[] arguments) {
		string root = ".";
		string suite = "";
		string testName = "";

		getopt(arguments, config.passThrough,
			"root",  &root,
			"suite|s", "the suite or package that you want to test", &suite,
			"test|t", "the suite or package that you want to test", &testName);

		version(Have_arsd_official_terminal) {} else {
			writeln("You can add `arsd-official:terminal` as a dependency to get coloured output");
		}

		Settings settings = readSettings(root);

		auto subPackage = arguments.find!(a => a[0] == ':');

		auto describe = root.dubDescribe(subPackage.empty ? "" : subPackage.front);
		auto modules = describe.findModules(subPackage.empty ? "" : subPackage.front);
		auto externalModules = describe.findExternalModules;
		auto hasTrialDependency = describe.hasTrial(subPackage.empty ? "" : subPackage.front);

		std.file.write(root ~ "/generated.d", generateTestFile(settings, hasTrialDependency, modules, externalModules, suite, testName));

		return arguments.runTests(root);
	}
}
