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
import trial.version_;

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
    PackageDescriptionCommand m_description;
    BuildSettingsTemplate tcinfo;
    bool hasTcinfo;
  }

  string reporters;
  string plugins;

  alias getDependency = Project.getDependency;
  alias getTopologicalPackageList = Project.getTopologicalPackageList;

  this(PackageDescriptionCommand description) {
    this.project = description.project;
    this.m_description = description;

    project.rootPackage.recipe.configurations = [ConfigurationInfo(m_description.buildFile, testBuildSettings)];

    super(project.packageManager, project.rootPackage);
    this.reinit;
  }

  PackageDescriptionCommand description() {
    return m_description;
  }

  bool hasTrialDependency() {
    return testBuildSettings.dependencies.keys.canFind("trial:lifecycle");
  }

  string embededLibraryPath() {
    auto settings = m_description.readSettings();
    return (NativePath(m_description.mainFile).parentPath ~ settings.artifactsLocation ~ "lifecycle").toNativeString();
  }

  BuildSettingsTemplate testBuildSettings() {
    if(hasTcinfo) {
      return tcinfo;
    }

    tcinfo = project.rootPackage.recipe.getConfiguration(m_description.configuration).buildSettings;
    tcinfo.targetType = TargetType.executable;
    tcinfo.targetName = m_description.buildFile;
    tcinfo.excludedSourceFiles[""] ~= tcinfo.mainSourceFile;
    tcinfo.importPaths[""] ~= NativePath(m_description.mainFile).parentPath.toNativeString();

    if(getBasePackageName(project.rootPackage.name) != "trial" && !tcinfo.dependencies.keys.canFind("trial:lifecycle")) {
      tcinfo.sourcePaths[""] ~= embededLibraryPath;
      tcinfo.stringImportPaths[""] ~= embededLibraryPath;
    }

    tcinfo.mainSourceFile = m_description.mainFile;
    tcinfo.versions[""] ~= "VibeCustomMain";

    import std.stdio;


    string[] plugins = m_description.readSettings().plugins ~ this.plugins.split(",").map!(a => a.strip).array;
    writeln("??????????", plugins);

    foreach(plugin; plugins) {
      if(plugin in tcinfo.dependencies) {
        continue;
      }

      auto pluginPackage = getPackage(plugin, Dependency.any);
      tcinfo.dependencies[plugin] = Dependency(pluginPackage.version_);

      import std.stdio;
      writeln("---=====>", tcinfo.dependencies.keys);
    }

    project.saveSelections;
    hasTcinfo = true;
    return tcinfo;
  }

  Package getPackage(string name, Dependency dep) {
    auto baseName = name.canFind(":") ? name.split(":")[0] : name;
    bool isSelected;

    if(baseName == getBasePackageName(project.name)) {
      return null;
    }

    if(project.selections.hasSelectedVersion(baseName)) {
      dep = project.selections.getSelectedVersion(baseName);
      dep.optional = false;
    }

    Package pack;

    if(!dep.optional && dep.path.toString != "") {
      if(!dep.path.absolute) {
        dep.path = project.rootPackage.path ~ dep.path;
      }

      project.packageManager.getOrLoadPackage(dep.path, NativePath.init, true);
    }

    /// if the package is not optional
    if(!dep.optional) {
      pack = project.packageManager.getBestPackage(name, dep, true);
    }

    /// it the package can not be resolved, it means it is not cached
    if(pack is null && !dep.optional) {
      m_description.dub.fetch(baseName, dep, PlacementLocation.user, FetchOptions.usePrerelease);
      pack = project.packageManager.getBestPackage(baseName, dep, true);

      if(pack is null) {
        pack = project.packageManager.getPackage(baseName, dep.version_);
      }
    }

    if(pack !is null) {
      if(!isSelected) {
        project.selections.selectVersion(pack.basePackage.name, pack.version_);
      }

      foreach(dependency; pack.getAllDependencies) {
        getPackage(dependency.name, dependency.spec);
      }
    }

    return pack;
  }

  void writeTestFile() {
    auto settings = m_description.readSettings();

    if (reporters != "") {
      settings.reporters = reporters.split(",").map!(a => a.strip).array;
    }

    if (plugins != "") {
      settings.plugins = plugins.split(",").map!(a => a.strip).array;
    }

    if(!hasTrialDependency) {
      writeTrialFolder(embededLibraryPath);
    }

    auto content = generateTestFile(settings, m_description.hasTrial, m_description.modules, m_description.externalModules);

    auto mainFile = m_description.mainFile;

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
}

class TrialCommand : PackageBuildCommand {
  protected {
    bool m_combined;
    bool m_parallel;
    bool m_force;
    string m_testName;
    string m_suiteName;
    string m_reporters;
    string m_executor;
    string m_plugins;
    TrialProject project;
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

  void setProject(TrialProject project) {
    this.project = project;
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
    
    args.getopt("e|executor", &m_executor,
        ["Override the test executor"]);

    args.getopt("p|plugins", &m_plugins,
        ["Add a trial plugin as dependency from code.dlang.org. eg. -p trial-plugin1,trial-plugin2"]);

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

    logInfo("Generate main file: " ~ project.description.mainFile);

    import std.stdio;
    writeln("m_plugins: ", m_plugins);
    project.plugins = m_plugins;
    project.reporters = m_reporters;
    project.writeTestFile();

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

    if (m_executor != "") {
      arguments ~= ["-e", m_executor];
    }

    run(arguments);

    return 0;
  }

  void run(string[] runArgs = []) {
    auto settings = getSettings;
    settings.runArgs = runArgs;

    auto generator = createProjectGenerator("build", project);
 
    generator.generate(settings);
  }

  protected GeneratorSettings getSettings() {
    auto m_description = project.description;

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
        auto m_description = project.description;

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
    auto list = [project.description.getRootPackage] ~ project.description.subPackages;
    list.join("\n").writeln;

    return 0;
  }
}
