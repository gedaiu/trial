module trial.generator;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;

import trial.settings;

string generateTestFile(Settings settings, bool hasTrialDependency, string[] modules, string suite = "", string testName = "") {
  if(suite != "") {
    writeln("Selecting suites conaining `" ~ suite ~ "`.");
  }

  testName = testName.replace(`"`, `\"`);
  if(testName != "") {
    writeln("Selecting tests conaining `" ~ testName ~ "`.");
  }

    enum d =
      import("discovery.d") ~
      import("runner.d") ~
      import("interfaces.d") ~
      import("settings.d") ~
      import("reporters/writer.d") ~
      import("reporters/result.d") ~
      import("reporters/spec.d");

    string code;

    if(hasTrialDependency) {
      writeln("We are using the project `trial:lifecicle` dependency.");

      code = "
        import trial.discovery;
        import trial.runner;
        import trial.interfaces;
        import trial.settings;
        import trial.reporters.result;
        import trial.reporters.spec;\n";
    } else {
      writeln("We will embed the `trial:lifecicle` code inside the project.");

      code = d.split("\n")
              .filter!(a => !a.startsWith("module"))
              .filter!(a => !a.startsWith("@(\""))
              .filter!(a => a.indexOf("import") == -1 || a.indexOf("trial.") == -1)
              .join("\n")
              .removeUnittests;
    }

    code ~= `
    void main() {
        TestDiscovery testDiscovery;`;

    code ~= modules
      .filter!(a => a.indexOf(suite) != -1)
      .map!(a => `        testDiscovery.addModule!"` ~ a ~ `";`)
      .join("\n");

    code ~= `
        setupLifecycle(` ~ settings.toCode ~ `);
        runTests(testDiscovery, "` ~ testName ~ `");
    }

    version (unittest) shared static this()
    {
        import core.runtime;
        Runtime.moduleUnitTester = () => true;
    }`;

    return code;
}

version(unittest) {
  import std.datetime;
  import fluent.asserts;
}

string removeTest(string data) {
  auto cnt = 0;

  if(data[0] == ')') {
    return "unittest" ~ data;
  }

  if(data[0] != '{') {
    return data;
  }

  foreach(size_t i, ch; data) {
    if(ch == '{') {
      cnt++;
    }

    if(ch == '}') {
      cnt--;
    }

    if(cnt == 0) {
      return data[i+1..$];
    }
  }

  return data;
}

string removeUnittests(string data) {
  auto pieces = data.split("unittest");

  return pieces
          .map!(a => a.strip.removeTest)
          .join("\n")
          .split("version(\nunittest)")
          .map!(a => a.strip.removeTest)
          .join("\n")
          .split("\n")
          .map!(a => a.stripRight)
          .join("\n");

}

@("It should remove unit tests")
unittest{
  `module test;

  @("It should find this test")
  unittest
  {
    import trial.discovery;
    {}{{}}
  }

  int main() {
    return 0;
  }`.removeUnittests.should.equal(`module test;

  @("It should find this test")


  int main() {
    return 0;
  }`);
}

@("It should remove unittest versions")
unittest{
  `module test;

  version(    unittest  )
  {
    import trial.discovery;
    {}{{}}
  }

  int main() {
    return 0;
  }`.removeUnittests.should.equal(`module test;


  int main() {
    return 0;
  }`);
}
