module trial.command;

import std.exception;
import trial.description;

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

class TrialCommand : PackageBuildCommand {
	private {
		bool m_combined = false;
		bool m_parallel = false;
		bool m_force = false;
		string m_testName = "";
		PackageDescriptionCommand m_description;
	}

	this()
	{
		this.name = "test";
		this.argumentsPattern = "[<package>]";
		this.description = "Executes the tests of the selected package";
		this.helpText = [
			`Builds the package and executes all contained unit tests.`,
			``,
			`If no explicit configuration is given, an existing "unittest" ` ~
			`configuration will be preferred for testing. If none exists, the ` ~
			`first library type configuration will be used, and if that doesn't ` ~
			`exist either, the first executable configuration is chosen.`,
			``,
			`When a custom main file (--main-file) is specified, only library ` ~
			`configurations can be used. Otherwise, depending on the type of ` ~
			`the selected configuration, either an existing main file will be ` ~
			`used (and needs to be properly adjusted to just run the unit ` ~
			`tests for 'version(unittest)'), or DUB will generate one for ` ~
			`library type configurations.`,
			``,
			`Finally, if the package contains a dependency to the "tested" ` ~
			`package, the automatically generated main file will use it to ` ~
			`run the unit tests.`
		];
		this.acceptsAppArgs = true;
	}

	void setDescription(PackageDescriptionCommand description) {
		m_description = description;
	}

	override void prepare(scope CommandArgs args)
	{
		args.getopt("combined", &m_combined, [
			"Tries to build the whole project in a single compiler run."
		]);
		args.getopt("parallel", &m_parallel, [
			"Runs multiple compiler instances in parallel, if possible."
		]);
		args.getopt("f|force", &m_force, [
			"Forces a recompilation even if the target is up to date."
		]);

		args.getopt("t|test", &m_testName, [
			"It will run all the tests that contain this text in the name."
		]);

		bool coverage = false;
		args.getopt("coverage", &coverage, [
			"Enables code coverage statistics to be generated."
		]);
		if (coverage) m_buildType = "unittest-cov";

		super.prepare(args);
	}

	override int execute(Dub dub, string[] free_args, string[] app_args)
	{
		string package_name;
		enforce(free_args.length <= 1, "Expected one or zero arguments.");
		if (free_args.length >= 1) package_name = free_args[0];

		logInfo("Generate main file: " ~ m_description.mainFile);
		m_description.writeTestFile(m_testName);

		setupPackage(dub, package_name, "unittest");

		GeneratorSettings settings;
		settings.platform = m_buildPlatform;
		settings.compiler = getCompiler(m_buildPlatform.compilerBinary);
		settings.buildType = m_buildType;
		settings.buildMode = m_buildMode;
		settings.buildSettings = m_buildSettings;
		settings.combined = m_combined;
		settings.parallelBuild = m_parallel;
		settings.force = m_force;
		settings.tempBuild = m_single;
		settings.run = true;
		settings.runArgs = app_args;

		dub.testProject(settings, m_buildConfig, dub.rootPath ~ Path("generated.d"));
		return 0;
	}
}