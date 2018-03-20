module trial.command;

import std.exception;
import std.algorithm;
import std.stdio;
import std.string;
import std.file;
import std.datetime;
import std.path;
import std.array;
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

class TrialProject : Project {

  private {
    Project project;
    Project trialProject;
    PackageDescriptionCommand m_description;
  }
  alias getDependency = Project.getDependency;
  alias getTopologicalPackageList = Project.getTopologicalPackageList;

  this(Project project, PackageDescriptionCommand description) {
    this.project = project;
    this.m_description = description;

    project.rootPackage.recipe.configurations = [ConfigurationInfo(m_description.buildFile, testBuildSettings)];

    super(project.packageManager, project.rootPackage);
    this.reinit;
  }

  override
  inout(Package) getDependency(string name, bool is_optional)
  inout {
    auto result = super.getDependency(name, is_optional);


    if(result !is null) {
      auto basename = getBasePackageName(name);
      auto recipe = result.recipe.clone;
      auto hasTrialConfigurations = recipe.configurations.canFind!(a => a.name == "trial");

      if(basename != rootPackage.basePackage.name && hasTrialConfigurations) {
        recipe.configurations = recipe.configurations.filter!(a => a.name != "trial").array;

        return cast(inout Package) new Package(recipe, result.path, cast(Package) result.parentPackage, result.recipe.version_);
      }
    }

    return result;
  }

  BuildSettingsTemplate testBuildSettings() {
    BuildSettingsTemplate tcinfo = project.rootPackage.recipe.getConfiguration(m_description.configuration).buildSettings;

    tcinfo.targetType = TargetType.executable;
    tcinfo.targetName = m_description.buildFile;
    tcinfo.excludedSourceFiles[""] ~= tcinfo.mainSourceFile;
    tcinfo.importPaths[""] ~= NativePath(m_description.mainFile).parentPath.toNativeString();
    tcinfo.mainSourceFile = m_description.mainFile;
    tcinfo.versions[""] ~= "VibeCustomMain";

    if(getBasePackageName(project.rootPackage.name) != "trial") {
      auto trialPackage = getPackage("trial:lifecycle", Dependency.any);
      tcinfo.dependencies["trial:lifecycle"] = Dependency(trialPackage.version_);
    }

    project.saveSelections;

    return tcinfo;
  }

  Package getPackage(string name, Dependency dep) {
    auto baseName = name.canFind(":") ? name.split(":")[0] : name;

    if(project.selections.hasSelectedVersion(baseName)) {
      dep = project.selections.getSelectedVersion(baseName);
      dep.optional = false;
    }

    Package pack;

    if(!dep.optional) {
      pack = project.packageManager.getBestPackage(name, dep, true);
    }

    if(pack is null && !dep.optional) {
      m_description.dub.fetch(baseName, Dependency.any, PlacementLocation.user, FetchOptions.none);
      pack = project.packageManager.getBestPackage(baseName, dep, true);

      if(pack is null) {
        pack = project.packageManager.getPackage(baseName, dep.version_);
      }
    }

    if(pack !is null) {
      project.selections.selectVersion(pack.basePackage.name, pack.version_);

      foreach(dependency; pack.getAllDependencies) {
        getPackage(dependency.name, dependency.spec);
      }
    }

    return pack;
  }
}

class TrialCommand : PackageBuildCommand {
  protected {
    bool m_combined = false;
    bool m_parallel = false;
    bool m_force = false;
    string m_testName = "";
    string m_suiteName = "";
    string m_reporters = "";
    PackageDescriptionCommand m_description;
  }

  this() {
    this.name = "trial";
    this.argumentsPattern = "[<package>]";
    this.description = "Executes the tests of the selected package";
    this.helpText = [`Builds the package and executes all contained test.`, ``,
      `If no explicit configuration is given, an existing "trial" `
      ~ `configuration will be preferred for testing. If none exists, the `
      ~ `first library type configuration will be used, and if that doesn't `
      ~ `exist either, the first executable configuration is chosen.`];
    this.acceptsAppArgs = false;
  }

  void setDescription(PackageDescriptionCommand description) {
    m_description = description;
  }

  override void prepare(scope CommandArgs args) {
    m_buildType = "unittest";

    args.getopt("combined", &m_combined,
        ["Tries to build the whole project in a single compiler run."]);
    args.getopt("parallel", &m_parallel,
        ["Runs multiple compiler instances in parallel, if possible."]);
    args.getopt("f|force", &m_force,
        ["Forces a recompilation even if the target is up to date."]);

    args.getopt("t|test", &m_testName,
        ["It will run all the tests that contain this text in the name."]);

    args.getopt("s|suite", &m_suiteName,
        ["It will run all the suites that contain this text in the name."]);

    args.getopt("r|reporters", &m_reporters,
        ["Override the reporters from the `trial.json` file. eg. -r spec,result,stats"]);

    bool coverage = false;
    args.getopt("coverage", &coverage, ["Enables code coverage statistics to be generated."]);
    if (coverage)
      m_buildType = "unittest-cov";

    super.prepare(args);
  }

  override int execute(Dub dub, string[] free_args, string[] app_args = []) {
    string package_name;

    enforce(free_args.length <= 1, "Expected one or zero arguments.");

    if (free_args.length >= 1) {
      package_name = free_args[0];
    }

    logInfo("Generate main file: " ~ m_description.mainFile);
    m_description.writeTestFile(m_reporters);

    setupPackage(dub, package_name, m_buildType);

    m_buildSettings.addOptions([BuildOption.unittests, BuildOption.debugMode,
        BuildOption.debugInfo]);

    string[] arguments;

    if (m_testName != "") {
      arguments ~= ["-t", m_testName];
    }

    if (m_suiteName != "") {
      arguments ~= ["-s", m_suiteName];
    }

    run(arguments);

    return 0;
  }

  void run(string[] runArgs = []) {
    auto settings = getSettings;

    settings.runArgs = runArgs;

    auto project = m_description.project;
    auto config = settings.config;

    auto trialProject = new TrialProject(project, m_description);
    auto generator = createProjectGenerator("build", trialProject);
 
    generator.generate(settings);
  }

  protected GeneratorSettings getSettings() {
    GeneratorSettings settings;
    settings.config = m_description.configuration;
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
    settings.runArgs = [];
    settings.buildSettings.mainSourceFile = m_description.mainFile;
    settings.config = m_description.buildFile;

    return settings;
  }
}

class TrialDescribeCommand : TrialCommand {

  this() {
    this.name = "describe";
    this.argumentsPattern = "[<package>]";
    this.description = "lists the tests of the selected package";
    this.helpText = [`Builds the package and lists all contained tests.`, ``,
      `If no explicit configuration is given, an existing "trial" `
      ~ `configuration will be preferred for testing. If none exists, the `
      ~ `first library type configuration will be used, and if that doesn't `
      ~ `exist either, the first executable configuration is chosen.`];

    this.acceptsAppArgs = true;
  }

  override {
    void setDescription(PackageDescriptionCommand description) {
      m_description = description;
    }

    void prepare(scope CommandArgs args) {
      m_buildType = "unittest";
      super.prepare(args);
    }

    int execute(Dub dub, string[] free_args, string[] app_args = []) {
      import trial.runner;
      import trial.discovery.unit;
      import trial.discovery.testclass;
      import trial.discovery.spec;
      import trial.interfaces;
      import std.array : array;

      auto unitTestDiscovery = new UnitTestDiscovery;
      auto testClassDiscovery = new TestClassDiscovery;
      auto specDiscovery = new SpecTestDiscovery;
      TestCase[] testCases;

      enforce(free_args.length <= 1, "Expected one or zero arguments.");

      if (free_args.length == 1 && exists(free_args[0])) {
        testCases = unitTestDiscovery.discoverTestCases(free_args[0]);
        testCases ~= testClassDiscovery.discoverTestCases(free_args[0]);
        testCases ~= specDiscovery.discoverTestCases(free_args[0]);
      } else {
        testCases = m_description.files.map!(a => unitTestDiscovery.discoverTestCases(a))
          .join.array;
        testCases ~= m_description.files.map!(a => testClassDiscovery.discoverTestCases(a))
          .join.array;
        testCases ~= m_description.files.map!(a => specDiscovery.discoverTestCases(a)).join.array;
      }

      testCases.describeTests.toJSONHierarchy.write;

      return 0;
    }
  }
}

class TrialSubpackagesCommand : TrialCommand {
  this() {
    this.name = "subpackages";
    this.argumentsPattern = "";
    this.description = "lists the project subpackages";
    this.helpText = [`Searches trough the dub package and lists all the defined sub packages`];

    this.acceptsAppArgs = false;
  }

  override int execute(Dub dub, string[] free_args, string[] app_args = []) {
    auto list = [m_description.getRootPackage] ~ m_description.subPackages;
    list.join("\n").writeln;

    return 0;
  }
}
