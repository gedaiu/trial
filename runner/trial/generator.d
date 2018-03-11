module trial.generator;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.exception;

import dub.internal.vibecompat.core.log;

import trial.settings;

///
string generateDiscoveries(string[] discoveries, string[2][] modules) {
  string code;

  uint index;
  foreach(discovery; discoveries) {
    string[] pieces = discovery.split(".");
    string cls = pieces[pieces.length - 1];

    if(pieces[0] != "trial") {
      code ~= "\n    import " ~ pieces[0..$-1].join(".") ~ ";\n";
    }

    code ~= "      auto testDiscovery" ~ index.to!string ~ " = new " ~ cls ~ ";\n";

    foreach(m; modules) {
      code ~= `      testDiscovery` ~ index.to!string ~ `.addModule!(` ~ "`" ~ m[0] ~ "`" ~ `, ` ~ "`" ~ m[1] ~ "`" ~ `);` ~ "\n";
    }

    code ~= "\n      LifeCycleListeners.instance.add(testDiscovery" ~ index.to!string ~ ");\n\n";
    index++;
  }

  return code;
}

string generateTestFile(Settings settings, bool hasTrialDependency, string[2][] modules, string[] externalModules) {

  string code = "
      import std.getopt;
      import trial.discovery.unit;
      import trial.discovery.spec;
      import trial.discovery.testclass;
      import trial.runner;
      import trial.interfaces;
      import trial.settings;
      import trial.stackresult;
      import trial.reporters.result;
      import trial.reporters.stats;
      import trial.reporters.spec;
      import trial.reporters.specsteps;
      import trial.reporters.dotmatrix;
      import trial.reporters.landing;
      import trial.reporters.progress;
      import trial.reporters.xunit;
      import trial.reporters.tap;
      import trial.reporters.visualtrial;
      import trial.reporters.result;\n";

  code ~= settings.plugins
    .map!(a => a.toLower.replace("-", ""))
    .map!(a => a.toLower.replace(":", "."))
    .map!(a => "      import " ~ a ~ ".plugin;")
    .join("\n");

  code ~= `
  int main(string[] arguments) {
      string testName;
      string suiteName;
      string executor;

      getopt(
        arguments,
        "testName|t",  &testName,
        "suiteName|s",  &suiteName,
        "executor|e",  &executor
      );

      auto settings = ` ~ settings.toCode ~ `;
      if(executor != "") {
        settings.executor = executor;
      }

      setupLifecycle(settings);` ~ "\n\n";

  if(hasTrialDependency) {
    externalModules ~= [ "_d_assert", "std.", "core." ];

    code~= `
      StackResult.externalModules = ` ~ externalModules.to!string ~ `;
    `;
  }

  code ~= generateDiscoveries(settings.testDiscovery, modules);

  code ~= `
      if(arguments.length > 1 && arguments[1] == "describe") {
        import std.stdio;
        describeTests.toJSONHierarchy.write;
        return 0;
      } else {
        return runTests(LifeCycleListeners.instance.getTestCases, testName, suiteName).isSuccess ? 0 : 1;
      }
  }

  version (unittest) shared static this()
  {
      import core.runtime;
      Runtime.moduleUnitTester = () => true;
  }`;

  return code;
}