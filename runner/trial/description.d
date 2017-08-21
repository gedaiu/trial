module trial.description;

import std.array;
import std.algorithm;
import std.file;
import std.path;
import std.conv;

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

class PackageDescriptionCommand : PackageBuildCommand
{

    private
    {
        Dub dub;
        ProjectDescription desc;
        string subPackageName;
        string rootPackage;
        TargetDescription[] neededTarget;
    }

    this(CommonOptions options, string subPackageName)
    {
        dub = createDub(options);
        setupPackage(dub, subPackageName);

        this.subPackageName = subPackageName;
        this.desc = dub.project.describe(getSettings);
        this.rootPackage = this.desc.rootPackage;

        this.neededTarget = this.desc.targets.filter!(a => a.rootPackage.canFind(rootPackage))
            .filter!(a => a.rootPackage.canFind(subPackageName)).array;
    }

    GeneratorSettings getSettings() {
        GeneratorSettings settings;
        settings.platform = m_buildPlatform;
        settings.config = configuration;
        settings.buildType = m_buildType;
        settings.compiler = m_compiler;
        settings.buildSettings.addOptions([ BuildOption.unittests, BuildOption.debugMode, BuildOption.debugInfo ]);

        return settings;
    }

    string configuration()
    {
        if(m_buildConfig.length) {
            return m_buildConfig;
        }

        if(hasTrialConfiguration) {
            return "trial";
        }

        return dub.project.getDefaultConfiguration(m_buildPlatform);
    }

    bool hasTrialConfiguration()
    {
        return dub.configurations.canFind("trial");
    }

    auto targets()
    {
        return this.desc.targets;
    }

    auto modules()
    {
        logInfo("Looking for files inside `" ~ rootPackage ~ "`");

        auto currentPackage = this.desc.packages.filter!(a => a.name == rootPackage).front;

        auto packagePath = currentPackage.path;

        if (neededTarget.empty)
        {
            string[2][] val;
            return val;
        }

        return neededTarget.front.buildSettings.sourceFiles.map!(a => a.to!string)
            .filter!(a => a.startsWith(packagePath)).map!(a => [a,
                    getModuleName(a)]).filter!(a => a[1] != "").array.to!(string[2][]);
    }

    string[] externalModules()
    {
        auto neededTargets = this.desc.targets.filter!(a => !a.rootPackage.canFind(rootPackage));

        if (neededTargets.empty)
        {
            return [];
        }

        auto files = cast(string[]) reduce!((a, b) => a ~ b)([],
                neededTargets.map!(a => a.buildSettings.sourceFiles));

        return files.map!(a => getModuleName(a)).filter!(a => a != "").array;
    }

    bool hasTrial()
    {
        if(rootPackage == "trial") {
            return true;
        }

        if (neededTarget.empty)
        {
            return false;
        }

        return !neededTarget[0].buildSettings.versions.filter!(
                a => a.canFind("Have_trial")).empty;
    }

    override int execute(Dub dub, string[] free_args, string[] app_args)
    {
        assert(false);
    }

    Settings readSettings(Path root)
    {
        string path = (root ~ Path("trial.json")).to!string;

        if (!path.exists)
        {
            Settings def;
            std.file.write(path, def.serializeToJson.toPrettyString);
        }

        Settings settings = readText(path).deserializeJson!Settings;

        return settings;
    }

    void writeTestFile(string testName = "")
    {
        auto content = generateTestFile(readSettings(dub.rootPath), hasTrial, modules, externalModules, testName);
        std.file.write(mainFile, content);
    }

    string mainFile()
    {
        return (dub.rootPath ~ Path("generated.d")).to!string;
    }
}
