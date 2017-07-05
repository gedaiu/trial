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
import trial.discovery.code;
import trial.coverage;

Settings readSettings(Path root) {
	string path = (root ~ Path("trial.json")).to!string;

	if(!path.exists) {
		Settings def;
		std.file.write(path, def.serializeToJson.toPrettyString);
	}

	Settings settings = readText(path).deserializeJson!Settings;

	return settings;
}

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

class PackageDescription : PackageBuildCommand {

	private {
		Dub dub;
		ProjectDescription desc;
		string subPackageName;
		string rootPackage;
		TargetDescription[] neededTarget;
	}

	this(CommonOptions options, string subPackageName) {
		dub = createDub(options);

		logInfo("setup package: " ~ subPackageName);
		setupPackage(dub, subPackageName);

		m_defaultConfig = dub.project.getDefaultConfiguration(m_buildPlatform);

		auto config = m_buildConfig.length ? m_buildConfig : m_defaultConfig;

		GeneratorSettings settings;
		settings.platform = m_buildPlatform;
		settings.config = config;
		settings.buildType = m_buildType;
		settings.compiler = m_compiler;

		this.subPackageName = subPackageName;
		this.desc = dub.project.describe(settings);
		this.rootPackage = this.desc.rootPackage;

		this.neededTarget = this.desc.targets
			.filter!(a => a.rootPackage.canFind(rootPackage))
			.filter!(a => a.rootPackage.canFind(subPackageName)).array;
	}

	auto targets() {
		return this.desc.targets;
	}

	auto modules() {
		logInfo("Looking for files inside `" ~ rootPackage ~ "`");

		auto currentPackage = this.desc.packages
			.filter!(a => a.name == rootPackage)
			.front;

		auto packagePath = currentPackage.path;

		if(neededTarget.empty) {
			string[2][] val;
			return val;
		}

		return neededTarget.front.buildSettings.sourceFiles
			.map!(a => a.to!string)
			.filter!(a => a.startsWith(packagePath))
			.map!(a => [a, getModuleName(a)])
			.filter!(a => a[1] != "")
				.array.to!(string[2][]);
	}

	string[] externalModules() {
		auto neededTargets = this.desc.targets.filter!(a => !a.rootPackage.canFind(rootPackage));

		if(neededTargets.empty) {
			return [];
		}

		auto files = cast(string[]) reduce!((a, b) => a ~ b)([], neededTargets.map!(a => a.buildSettings.sourceFiles));

		return files
			.map!(a => getModuleName(a))
			.filter!(a => a != "")
				.array;
	}

	bool hasTrial() {
		if(neededTarget.empty) {
			return false;
		}

		return !neededTarget[0].buildSettings.versions.filter!(a => a == "Have_trial_lifecycle").empty;
	}

	override int execute(Dub dub, string[] free_args, string[] app_args) {
		assert(false);
	}

	void writeTestFile(string content) {
		std.file.write(mainFile, content);
	}

	string mainFile() {
		return (dub.rootPath ~ Path("generated.d")).to!string;
	}
}

Dub createDub(CommonOptions options) {
	Dub dub;

	if (options.bare) {
		dub = new Dub(Path(getcwd()));
		dub.rootPath = Path(options.root_path);
		dub.defaultPlacementLocation = options.placementLocation;

		return dub;
	}

	// initialize DUB
	auto package_suppliers = options.registry_urls.map!(url => cast(PackageSupplier)new RegistryPackageSupplier(URL(url))).array;
	dub = new Dub(options.root_path, package_suppliers, options.skipRegistry);

	dub.dryRun = options.annotate;
	dub.defaultPlacementLocation = options.placementLocation;

	// make the CWD package available so that for example sub packages can reference their
	// parent package.
	try {
		dub.packageManager.getOrLoadPackage(Path(options.root_path));
	} catch (Exception e) {
		logDiagnostic("No package found in current working directory.");
	}

	return dub;
}

version(unitttest) {} else {
	int main(string[] arguments) {
		string testName = "";

		getopt(arguments, config.passThrough,
			"test|t", "the suite or package that you want to test", &testName);

		version(Have_arsd_official_terminal) {} else {
			logInfo("\nYou can add `arsd-official:terminal` as a dependency to get coloured output\n");
		}

		version(Windows){
			environment["TEMP"] = environment["TEMP"].replace("/", "\\");
		}

		arguments = arguments[1..$];
		auto subPackage = arguments.find!(a => a[0] == ':');
		auto subPackageName = subPackage.empty ? "" : subPackage.front;

		arguments = arguments.filter!(a => a.indexOf("--main-file=") != 0).array;
		auto options = parseGeneralOptions(arguments);
		auto commandArgs = new CommandArgs(arguments);

		auto dub = createDub(options);

		auto description = new PackageDescription(options, subPackageName);

		Settings settings = readSettings(dub.rootPath);

		auto modules = description.modules;
		auto externalModules = description.externalModules;
		auto hasTrialDependency = description.hasTrial;

		logInfo("Generate main file: " ~ description.mainFile);
		description.writeTestFile(generateTestFile(settings, hasTrialDependency, modules, externalModules, testName));
		arguments ~= ["--main-file=" ~ description.mainFile];

		options = parseGeneralOptions(arguments);
		commandArgs = new CommandArgs(arguments);
		auto packageName = subPackage.empty ? [] : [ subPackage.front ];

		auto cmd = new TestCommand;
		cmd.prepare(commandArgs);

		auto remainingArgs = commandArgs.extractRemainingArgs();

		if (remainingArgs.any!(a => a.startsWith("-"))) {
			logError("Unknown command line flags: %s", remainingArgs.filter!(a => a.startsWith("-")).array.join(" "));
			return 1;
		}

		try {
			cmd.execute(dub, remainingArgs, []);
		} catch(Exception e) {
			return 1;
		} finally {
			convertLstFiles(dub.rootPath.toString, dub.projectName);
		}

		return 0;
	}
}
