module trial;


public import trial.attributes;
public import trial.runner;
public import trial.discovery.code;
public import trial.discovery.spec;
public import trial.discovery.testclass;
public import trial.discovery.unit;
public import trial.executor.parallel;
public import trial.executor.process;
public import trial.executor.single;
public import trial.interfaces;
public import trial.reporters.allure;
public import trial.reporters.dotmatrix;
public import trial.reporters.html;
public import trial.reporters.landing;
public import trial.reporters.list;
public import trial.reporters.progress;
public import trial.reporters.result;
public import trial.reporters.spec;
public import trial.reporters.specprogress;
public import trial.reporters.specsteps;
public import trial.reporters.stats;
public import trial.reporters.tap;
public import trial.reporters.visualtrial;
public import trial.reporters.writer;
public import trial.reporters.xunit;
public import trial.runner;
public import trial.settings;
public import trial.stackresult;
public import trial.step;
public import trial.terminal;

import std.stdio;
import std.meta : Alias;
import std.traits : fullyQualifiedName;
import dub_test_root;

string getModuleFileName(alias m)() {
  string location;

  static foreach (member; __traits(allMembers, m)) {
    static if(__traits(compiles, __traits(getLocation, __traits(getMember, m, member)))) {{
      location = __traits(getLocation, __traits(getMember, m, member))[0];
    }}
  }

  return location;
}

auto getModules() {
  struct ModuleWithPath {
    string name;
    string path;
  }

  ModuleWithPath[] modules;

  foreach (m; dub_test_root.allModules) {
    static if (__traits(isModule, m)) {
      alias module_ = m;
    } else {
      alias module_ = Alias!(__traits(parent, m));
    }

    modules ~= ModuleWithPath(fullyQualifiedName!module_, getModuleFileName!(module_));
  }

  return modules;
}

shared static this() {
  import core.runtime : Runtime, UnitTestResult;
  import std.getopt : getopt;
  import core.stdc.stdlib;
  import trial.discovery.unit;
  import trial.discovery.spec;
  import trial.discovery.testclass;

  Runtime.extendedModuleUnitTester = function() {
    string testName;
    string suiteName;
    string executor;
    string reporters;

		auto args = Runtime.args;
    args.getopt(
      "testName|t",  &testName,
      "suiteName|s", &suiteName,
      "executor|e",  &executor,
      "reporters|r", &reporters
    );

    auto settings = Settings();
    settings.reporters = ["spec", "result", "stats", "html", "allure", "xunit"];
    settings.artifactsLocation = ".trial";
    settings.maxThreads = 1;

    auto unittestDiscovery = new UnitTestDiscovery();
    auto specTestDiscovery = new SpecTestDiscovery();
    auto testClassDiscovery = new TestClassDiscovery();

    LifeCycleListeners.instance.add(unittestDiscovery);
    LifeCycleListeners.instance.add(specTestDiscovery);
    LifeCycleListeners.instance.add(testClassDiscovery);

    enum allModules = getModules();

    static foreach(m; allModules) {
      unittestDiscovery.addModule!(m.path, m.name);
      specTestDiscovery.addModule!(m.path, m.name);
      testClassDiscovery.addModule!(m.path, m.name);
    }

    setupLifecycle(settings);

    runTests(LifeCycleListeners.instance.getTestCases, testName, suiteName);

    return UnitTestResult(1, 1, false, false);
  };
}
