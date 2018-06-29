module trial.description;

import std.array;
import std.algorithm;
import std.file;
import std.path;
import std.conv;
import std.string;
import std.json;
import std.digest.sha;

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

import trial.discovery.code;
import trial.settings;
import trial.generator;
import trial.jsonvalidation;
import trial.runnersettings;


Dub createDub(CommonOptions options) {
  Dub dub;

  if (options.bare) {
    dub = new Dub(NativePath(getcwd()));
    dub.rootPath = NativePath(options.root_path);
    dub.defaultPlacementLocation = options.placementLocation;

    return dub;
  }

  // initialize DUB
  auto package_suppliers = options
      .registry_urls
      .map!(url => URL(url))
      .map!(url => cast(PackageSupplier) new RegistryPackageSupplier(url))
        .array;

  dub = new Dub(options.root_path, package_suppliers, options.skipRegistry);

  dub.dryRun = options.annotate;
  dub.defaultPlacementLocation = options.placementLocation;

  // make the CWD package available so that for example sub packages can reference their
  // parent package.
  try {
    dub.packageManager.getOrLoadPackage(NativePath(options.root_path));
  }
  catch (Exception e) {
    logDiagnostic("No package found in current working directory.");
  }

  return dub;
}

class PackageDescriptionCommand : PackageBuildCommand {
  Dub dub;

  private {
    ProjectDescription desc;
    string subPackageName;
    string rootPackage;
    TargetDescription[] neededTarget;
    CommonOptions options;
  }

  RunnerSettings runnerSettings;

  this(CommonOptions options, string subPackageName) {
    this.options = options;
    dub = createDub(options);
    setupPackage(dub, subPackageName);

    this.subPackageName = subPackageName;
    this.desc = dub.project.describe(getSettings);
    this.rootPackage = this.desc.rootPackage;

    this.neededTarget = this.desc.targets.filter!(a => a.rootPackage.canFind(rootPackage))
      .filter!(a => a.rootPackage.canFind(subPackageName)).array;
  }

  string getSubPackageName() {
    return subPackageName;
  }

  GeneratorSettings getSettings() {
    GeneratorSettings settings;
    settings.platform = m_buildPlatform;
    settings.config = configuration;
    settings.buildType = m_buildType;
    settings.compiler = m_compiler;
    settings.buildSettings.addOptions([BuildOption.unittests,
        BuildOption.debugMode, BuildOption.debugInfo]);

    return settings;
  }

  auto project() {
    return dub.project;
  }

  string configuration() {
    if (m_buildConfig.length) {
      return m_buildConfig;
    }

    if (hasTrialConfiguration) {
      return "trial";
    }

    return dub.project.getDefaultConfiguration(m_buildPlatform);
  }

  bool hasTrialConfiguration() {
    return dub.configurations.canFind("trial");
  }

  auto targets() {
    return this.desc.targets;
  }

  auto modules() {
    logInfo("Looking for files inside `" ~ rootPackage ~ "`");

    auto currentPackage = this.desc.packages.filter!(a => a.name == rootPackage).front;
    auto packagePath = currentPackage.path;

    if (neededTarget.empty) {
      string[2][] val;
      return val;
    }

    return neededTarget.front.buildSettings.sourceFiles.map!(a => a.to!string)
      .filter!(a => a.startsWith(packagePath)).map!(a => [a, getModuleName(a)])
      .filter!(a => a[1] != "").array.to!(string[2][]);
  }

  auto files() {
    return neededTarget.front.buildSettings.sourceFiles.map!(a => a.to!string).array;
  }

  string[] subPackages() {
    auto subpackages = dub.packageManager.getOrLoadPackage(NativePath(options.root_path),
        NativePath.init, true).subPackages;

    auto outsidePackages = subpackages.filter!(a => a.path != "").array;
    auto embeddedPackages = subpackages.filter!(a => a.path == "").array;

    auto packages = embeddedPackages.map!(a => a.recipe.name).map!(a => ":" ~ a).array;

    packages ~= outsidePackages.map!(
        a => ":" ~ dub.packageManager.getOrLoadPackage(NativePath(a.path)).name).array;

    return packages;
  }

  string[] externalModules() {
    auto neededTargets = this.desc.targets.filter!(a => !a.rootPackage.canFind(rootPackage));

    if (neededTargets.empty) {
      return [];
    }

    auto files = cast(string[]) reduce!((a, b) => a ~ b)([],
        neededTargets.map!(a => a.buildSettings.sourceFiles));

    return files.map!(a => getModuleName(a)).filter!(a => a != "").array;
  }

  string getRootPackage() {
    return rootPackage;
  }

  bool hasTrial() {
    if (rootPackage == "trial") {
      return true;
    }

    if (neededTarget.empty) {
      return false;
    }

    return !neededTarget[0].buildSettings.versions.filter!(a => a.canFind("Have_trial")).empty;
  }

  override int execute(Dub dub, string[] free_args, string[] app_args) {
    assert(false);
  }

  string mainFile() {
    string name = subPackageName != "" ? subPackageName : "root";
    name = name.replace(":", "");

    return buildPath(options.root_path, "trial_" ~ name ~ ".d").to!string;
  }

  string buildFile() {
    string name = subPackageName != "" ? subPackageName : "root";
    name = name.replace(":", "");

    return "trial-" ~ name;
  }
}
