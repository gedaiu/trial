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

version(unittest) {
  bool executed;

  void mock() @system {
    executed = true;
  }

  void failureMock() @system {
    executed = true;
    assert(false);
  }
}

@("A suite runner should run a success test case and add it to the result")
unittest {
  TestCase[string] tests = ["0": TestCase("someTestCase", &mock) ];

  executed = false;

  SuiteRunner suiteRunner = SuiteRunner("Suite name", tests);

  auto begin = Clock.currTime - 1.msecs;
  suiteRunner.start();
  auto end = Clock.currTime + 1.msecs;

  suiteRunner.result.tests.length.should.equal(1);
  suiteRunner.result.tests[0].begin.should.be.between(begin, end);
  suiteRunner.result.tests[0].end.should.be.between(begin, end);
  suiteRunner.result.tests[0].status.should.be.equal(Test.Status.success);
  executed.should.equal(true);
}

@("A suite runner should run a failing test case and add it to the result")
unittest {
  TestCase[string] tests = ["0": TestCase("someTestCase", &failureMock) ];

  executed = false;

  SuiteRunner suiteRunner = SuiteRunner("Suite name", tests);

  auto begin = Clock.currTime - 1.msecs;
  suiteRunner.start();
  auto end = Clock.currTime + 1.msecs;

  suiteRunner.result.tests.length.should.equal(1);
  suiteRunner.result.tests[0].begin.should.be.between(begin, end);
  suiteRunner.result.tests[0].end.should.be.between(begin, end);
  suiteRunner.result.tests[0].status.should.be.equal(Test.Status.failure);

  executed.should.equal(true);
}

@("A suite runner should call the suite lifecycle listener methods")
unittest {
  TestCase[string] tests = ["0": TestCase("someTestCase", &mock) ];

  string[] order = [];
  class TestSuiteListener: ISuiteLifecycleListener {
    void begin(ref Suite) {
      order ~= "begin";
    }

    void end(ref Suite) {
      order ~= "end";
    }
  }

  SuiteRunner suiteRunner = SuiteRunner("Suite name", tests);
  suiteRunner.listeners.add(new TestSuiteListener);

  suiteRunner.start();

  order.should.equal(["begin", "end"]);
}
