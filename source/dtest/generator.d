module dtest.generator;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;

string generateTestFile(string[] modules) {
    enum d = import("discovery.d") ~ import("runner.d") ~ import("interfaces.d");

    auto code = d.split("\n")
                  .filter!(a => !a.startsWith("module"))
                  .filter!(a => a.indexOf("import") == -1 || a.indexOf("dtest.") == -1)
                  .join("\n");

    code ~= `
    void main() {
        TestDiscovery testDiscovery;`;

    foreach(m; modules) {
      code ~= `testDiscovery.addModule!"` ~ m ~ `";`;
    }

    code ~= `
        writeln("Found ", testDiscovery.testCases.length, " test cases");

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
  import dtest.interfaces;
  import dtest.runner;
  import dtest.discovery;

  import fluent.asserts;
}

@("It should find this test")
unittest
{
  import dtest.discovery;

	TestDiscovery testDiscovery;

	testDiscovery.addModule!("dtest.discovery");
}

@("A suite runner should set the data to an empty suite runner")
unittest {
  TestCase[string] tests;

  SuiteRunner suiteRunner = SuiteRunner("Suite name", tests);

  auto begin = Clock.currTime - 1.msecs;
  suiteRunner.start();
  auto end = Clock.currTime + 1.msecs;

  suiteRunner.result.name.should.equal("Suite name");
  suiteRunner.result.tests.length.should.equal(0);
  suiteRunner.result.begin.should.be.between(begin, end);
  suiteRunner.result.end.should.be.between(begin, end);
}

@("A suite runner should run a test case and add it to the result")
unittest {
  TestCase[string] tests;

  tests["0"] = TestCase("someTestCase", {});

  SuiteRunner suiteRunner = SuiteRunner("Suite name", tests);

  auto begin = Clock.currTime - 1.msecs;
  suiteRunner.start();
  auto end = Clock.currTime + 1.msecs;

  suiteRunner.result.tests.length.should.equal(1);
  suiteRunner.result.tests[0].begin.should.be.between(begin, end);
  suiteRunner.result.tests[0].end.should.be.between(begin, end);
  suiteRunner.result.tests[0].status.should.be.equal(Test.Status.success);
}
