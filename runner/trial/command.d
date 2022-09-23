module trial.command;

import std.exception;
import std.algorithm;
import std.stdio;
import std.string;
import std.file;
import std.datetime;
import std.path;
import std.conv;
import std.array;

import dub.internal.vibecompat.data.json;

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
import dub.commandline;

import trial.runnersettings;
import trial.generator;
import trial.version_;
import trial.discovery.code;
import trial.coverage;

import std.stdio;

class TrialProject {
  private {
    BuildSettingsTemplate tcinfo;
    bool hasTcinfo;

    Dub dub;
    Project project;
  }

  ProjectDescription desc;
  RunnerSettings runnerSettings;

  string configuration;
  string packageName;
  string reporters;
  string plugins;

  alias getDependency = Project.getDependency;
  alias getTopologicalPackageList = Project.getTopologicalPackageList;

  this(Dub dub, RunnerSettings runnerSettings) {
    this.dub = dub;
    this.runnerSettings = runnerSettings;
  }

  Project dubProject() {
    return dub.project;
  }

  Project testProject() {
    if(project !is null) {
      return project;
    }

    auto tcinfo = testBuildSettings;

    project = dubProject;

    logInfo("Creating a new configuration named `%s`.", buildFile);
    project.rootPackage.recipe.configurations ~= ConfigurationInfo(buildFile, tcinfo);

    return project;
  }

  bool hasTrialDependency() {
    return testBuildSettings.dependencies.keys.canFind("trial:lifecycle");
  }

  string embededLibraryPath() {
    return (NativePath(mainFile).parentPath ~ runnerSettings.settings.artifactsLocation ~ "lifecycle").toNativeString();
  }

  BuildSettingsTemplate testBuildSettings() {
    if(hasTcinfo) {
      return tcinfo;
    }

    enforce(configuration != "", "No test configuration was found.");

    logInfo("Building configuration using the `%s` configuration.", configuration);

    tcinfo = dubProject.rootPackage.recipe.getConfiguration(configuration).buildSettings;
    tcinfo.targetType = TargetType.executable;
    tcinfo.targetName = buildFile;
    tcinfo.excludedSourceFiles[""] ~= tcinfo.mainSourceFile;
    tcinfo.importPaths[""] ~= NativePath(mainFile).parentPath.toNativeString();

    if(getBasePackageName(dubProject.rootPackage.name) != "trial" && !tcinfo.dependencies.keys.canFind("trial:lifecycle")) {
      tcinfo.sourcePaths[""] ~= embededLibraryPath;
      tcinfo.stringImportPaths[""] ~= embededLibraryPath;
    }

    tcinfo.sourceFiles[""] ~= mainFile;
    tcinfo.versions[""] ~= "VibeCustomMain";

    string[] plugins = runnerSettings.settings.plugins;

    foreach(plugin; plugins) {
      if(plugin in tcinfo.dependencies) {
        continue;
      }

      auto pluginPackage = getPackage(plugin, Dependency.any);
      tcinfo.dependencies[plugin] = Dependency(pluginPackage.version_);
      tcinfo.dependencies[plugin].optional = true;
    }

    dubProject.saveSelections;
    hasTcinfo = true;
    return tcinfo;
  }

  Package getPackage(string name, Dependency dep) {
    logDiagnostic("get package '%s'", name);

    auto baseName = name.canFind(":") ? name.split(":")[0] : name;
    bool isSelected;

    if(baseName == getBasePackageName(dubProject.name)) {
      return null;
    }

    if(dubProject.selections.hasSelectedVersion(baseName)) {
      dep = dubProject.selections.getSelectedVersion(baseName);
      dep.optional = false;
    }

    Package pack;

    if(!dep.optional && dep.path.toString != "") {
      if(!dep.path.absolute) {
        dep.path = dubProject.rootPackage.path ~ dep.path;
      }

      dubProject.packageManager.getOrLoadPackage(dep.path, NativePath.init, true);
    }

    /// if the package is not optional
    if(!dep.optional) {
      pack = dubProject.packageManager.getBestPackage(name, dep, true);
    }

    /// it the package can not be resolved, it means it is not cached
    if(pack is null && !dep.optional) {
      dub.fetch(baseName, dep, PlacementLocation.user, FetchOptions.usePrerelease);
      pack = dubProject.packageManager.getBestPackage(baseName, dep, true);

      if(pack is null) {
        pack = dubProject.packageManager.getPackage(baseName, dep.version_);
      }
    }

    if(pack !is null) {
      if(!isSelected) {
        dubProject.selections.selectVersion(pack.basePackage.name, pack.version_);
      }

      foreach(dependency; pack.getAllDependencies) {
        getPackage(dependency.name, dependency.spec);
      }
    }

    return pack;
  }

  void writeTestFile() {
    logDiagnostic("write the test file to '%s'", mainFile);

    if (reporters != "") {
      runnerSettings.settings.reporters = reporters.split(",").map!(a => a.strip).array;
    }

    if (plugins != "") {
      runnerSettings.settings.plugins = plugins.split(",").map!(a => a.strip).array;
    }

    auto content = generateTestFile(runnerSettings.settings, this.hasTrial, this.modules, this.externalModules);


    if (!mainFile.exists) {
      std.file.write(mainFile, content);
      return;
    }

    auto hash1 = getStringHash(content);
    auto hash2 = getFileHash(mainFile);

    if(hash1 != hash2) {
      std.file.write(mainFile, content);
    }
  }

  auto modules() {
    logInfo("Looking for files inside `" ~ dubProject.name ~ "`");

    auto currentPackage = this.desc.packages.filter!(a => a.name == dubProject.rootPackage.name).front;
    auto packagePath = currentPackage.path;

    auto neededTarget = this.desc.targets.filter!(a => a.rootPackage.canFind(dubProject.rootPackage.name))
      .filter!(a => a.rootPackage.canFind(subPackageName)).array;

    if (neededTarget.empty) {
      string[2][] val;
      return val;
    }

    return neededTarget.front.buildSettings.sourceFiles.map!(a => a.to!string)
      .filter!(a => a.startsWith(packagePath)).map!(a => [a, getModuleName(a)])
      .filter!(a => a[1] != "").array.to!(string[2][]);
  }

  string[] externalModules() {
    auto neededTargets = this.desc.targets.filter!(a => !a.rootPackage.canFind(dubProject.rootPackage.name));

    if (neededTargets.empty) {
      return [];
    }

    auto files = cast(string[]) reduce!((a, b) => a ~ b)([],
        neededTargets.map!(a => a.buildSettings.sourceFiles));

    return files.map!(a => getModuleName(a)).filter!(a => a != "").array;
  }

  string subPackageName() {
    return "";
  }

  string mainFile() {
    string name = subPackageName != "" ? subPackageName : "root";
    name = name.replace(":", "");

    return buildPath(dub.rootPath.toNativeString, "trial_" ~ name ~ ".d").to!string;
  }

  string buildFile() {
    string name = subPackageName != "" ? subPackageName : "root";
    name = name.replace(":", "");

    return "trial-" ~ name;
  }

  bool hasTrial() {
    if (dubProject.rootPackage.name == "trial") {
      return true;
    }

    auto neededTarget = this.desc.targets.filter!(a => a.rootPackage.canFind(dubProject.rootPackage.name))
      .filter!(a => a.rootPackage.canFind(subPackageName)).array;

    if (neededTarget.empty) {
      return false;
    }

    return !neededTarget[0].buildSettings.versions.filter!(a => a.canFind("Have_trial")).empty;
  }

  bool hasTrialConfiguration() {
    return dub.configurations.canFind("trial");
  }
}

class TrialRunCommand : PackageBuildCommand {
  protected {
    TrialProject project;
    Dub dub;
  }

  RunnerSettings runnerSettings;

  this(RunnerSettings runnerSettings) {
    this.name = "run";
    this.argumentsPattern = "[<package>]";
    this.description = "Executes the tests of the selected package";
    this.helpText = [`Builds the package and executes all contained test.`, ``,
      `If no explicit configuration is given, an existing "trial" `
      ~ `configuration will be preferred for testing. If none exists, the `
      ~ `first library type configuration will be used, and if that doesn't `
      ~ `exist either, the first executable configuration is chosen.`];

    this.acceptsAppArgs = false;
    this.runnerSettings = runnerSettings;
  }

  override void prepare(scope CommandArgs args) {
    m_buildType = runnerSettings.buildType;

    super.prepare(args);
  }

  protected void setup(Dub dub, string[] free_args, string[] app_args = []) {
    enforce(loadCwdPackage(dub, true), "Can't load the package.");

    logInfo("Setup the Trial project.");

    this.project = new TrialProject(dub, runnerSettings);
    if(free_args.length >= 1) {
      this.project.packageName = free_args[0];
    }

    if(!m_buildConfig && this.project.hasTrialConfiguration) {
      m_buildConfig = "trial";
    }

    setupPackage(dub, this.project.packageName, m_buildConfig);
    this.project.configuration = m_buildConfig;

    this.dub = dub;
  }

  private bool loadCwdPackage(Dub dub, bool warn_missing_package) {
    bool found;
    foreach (f; packageInfoFiles)
      if (existsFile(dub.rootPath ~ f.filename))
      {
        found = true;
        break;
      }

    if (!found) {
      if (warn_missing_package) {
        logInfo("");
        logInfo("No package manifest (dub.json or dub.sdl) was found in");
        logInfo(dub.rootPath.toNativeString());
        logInfo("Please run DUB from the root directory of an existing package, or run");
        logInfo("\"dub init --help\" to get information on creating a new package.");
        logInfo("");
      }
      return false;
    }

    dub.loadPackage();

    return true;
  }

  override int execute(Dub dub, string[] free_args, string[] app_args = []) {
    enforce(free_args.length <= 1, "Expected one or zero arguments.");
    setup(dub, free_args, app_args);

    auto settings = getSettings;
    logInfo("Generate main file in `%s`", project.mainFile);

    settings.buildSettings.addOptions([BuildOption.unittests, BuildOption.debugMode, BuildOption.debugInfo]);
    settings.buildSettings.targetType = TargetType.executable;

    if(project.configuration == "") {
      project.configuration = this.configuration;
    }

    project.desc = project.testProject.describe(settings);
    project.writeTestFile();
    string[] arguments;

    if (runnerSettings.testName != "") {
      arguments ~= ["-t", runnerSettings.testName];
    }

    if (runnerSettings.suiteName != "") {
      arguments ~= ["-s", runnerSettings.suiteName];
    }

    if (runnerSettings.executor != "") {
      arguments ~= ["-e", runnerSettings.executor];
    }

    logDiagnostic("Running the tests");

    settings.runArgs = arguments;

    //dub.project = project.testProject;
    auto generator = createProjectGenerator("build", project.testProject);

    generator.generate(settings);

    if(runnerSettings.buildType == "unittest-cov") {
      string source = buildPath("coverage", "raw");
      string destination = buildPath(runnerSettings.settings.artifactsLocation, "coverage");
      logDiagnostic("calculate the code coverage");

      logInfo("");
      logInfo("Line coverage: %s%s", convertLstFiles(source, destination, dub.rootPath.toString, dub.projectName), "%");
      logInfo("");
    }

    return 0;
  }

  protected GeneratorSettings getSettings() {
    GeneratorSettings settings;
    settings.config = project.buildFile;
    settings.platform = m_buildPlatform;
    settings.compiler = getCompiler(m_buildPlatform.compilerBinary);
    settings.buildType = m_buildType;
    settings.buildMode = m_buildMode;
    settings.combined = runnerSettings.combined;
    settings.parallelBuild = runnerSettings.parallel;
    settings.force = runnerSettings.force;
    settings.tempBuild = m_single;
    settings.run = true;
    settings.runArgs = [];

    settings.buildSettings = m_buildSettings;
    settings.buildSettings.mainSourceFile = project.mainFile;
    settings.buildSettings.targetName = project.buildFile;
    settings.buildSettings.targetType = TargetType.executable;
    settings.buildSettings.addVersions(["Have_trial_lifecycle", "trial_lifecycle"]);

    return settings;
  }

  string configuration() {
    if (m_buildConfig.length) {
      return m_buildConfig;
    }

    if (project.hasTrialConfiguration) {
      return "trial";
    }

    auto defaultConfiguration = project.dubProject.getDefaultConfiguration(m_buildPlatform);

    if(defaultConfiguration == "") {
      defaultConfiguration = "unittest";
    }

    return defaultConfiguration;
  }

  auto dubDescription() {
    return project.dubProject.describe(getSettings);
  }

  auto neededTarget() {
    auto desc = dubDescription;
    auto rootPackage = desc.rootPackage;

    return desc.targets.filter!(a => a.rootPackage.canFind(rootPackage))
      .filter!(a => a.rootPackage.canFind(this.project.packageName)).array;
  }

  auto files() {
    return neededTarget.front.buildSettings.sourceFiles.map!(a => a.to!string).array;
  }
}

class TrialDescribeCommand : TrialRunCommand {

  this(RunnerSettings runnerSettings) {
    super(runnerSettings);

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
    void prepare(scope CommandArgs args) {
      m_buildType = runnerSettings.buildType;
      super.prepare(args);
    }

    int execute(Dub dub, string[] free_args, string[] app_args = []) {
      this.setup(dub, free_args, app_args);
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
        testCases = this.files.map!(a => unitTestDiscovery.discoverTestCases(a))
          .join.array;
        testCases ~= this.files.map!(a => testClassDiscovery.discoverTestCases(a))
          .join.array;
        testCases ~= this.files.map!(a => specDiscovery.discoverTestCases(a)).join.array;
      }

      testCases.describeTests.toJSONHierarchy.write;

      return 0;
    }
  }
}

class TrialSubpackagesCommand : TrialRunCommand {

  this(RunnerSettings runnerSettings) {
    super(runnerSettings);

    this.name = "subpackages";
    this.argumentsPattern = "";
    this.description = "lists the project subpackages";
    this.helpText = [`Searches trough the dub package and lists all the defined sub packages`];

    this.acceptsAppArgs = false;
  }

  override int execute(Dub dub, string[] free_args, string[] app_args = []) {
    setup(dub, free_args, app_args);

    auto list = [this.dubDescription.rootPackage] ~ this.dubDescription.packages.map!(a => a.name).array;
    list.join("\n").writeln;

    return 0;
  }
}
