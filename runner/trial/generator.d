module trial.generator;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;

string generateTestFile(string[] modules) {
    enum d =
      import("discovery.d") ~
      import("runner.d") ~
      import("interfaces.d") ~
      import("reporters/writer.d") ~
      import("reporters/result.d") ~
      import("reporters/spec.d");

    auto code = "version(Have_trial_lifecycle) {

  import trial.discovery;
  import trial.runner;
  import trial.interfaces;
  import trial.reporters.result;
  import trial.reporters.spec;

} else {
" ~ d.split("\n")
            .filter!(a => !a.startsWith("module"))
            .filter!(a => !a.startsWith("@(\""))
            .filter!(a => a.indexOf("import") == -1 || a.indexOf("trial.") == -1)
            .join("\n")
            .removeUnittests;

    code ~= `}
    void main() {
        TestDiscovery testDiscovery;`;

    foreach(m; modules) {
      code ~= `        testDiscovery.addModule!"` ~ m ~ `";` ~ "\n";
    }

    code ~= `
        runTests(testDiscovery);
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
