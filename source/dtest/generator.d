module dtest.generator;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;

string generateTestFile(string[] modules) {
    enum d = import("discovery.d") ~
      import("runner.d") ~
      import("interfaces.d") ~
      import("reporters/writer.d") ~
      import("reporters/result.d") ~
      import("reporters/spec.d");

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
  import dtest.step;
  import std.conv;

  bool executed;

  void mock() @system {
    executed = true;
  }

  void failureMock() @system {
    executed = true;
    assert(false);
  }

  void stepFunction(int i) {
    Step("Step " ~ i.to!string);
  }

  void stepMock() @system {
    auto a = Step("some step");

    for(int i=0; i<3; i++) {
      stepFunction(i);
    }
  }
}

@("A suite runner should run a success test case and add it to the result")
unittest {
  TestCase[string] tests = ["0": TestCase("someTestCase", &mock) ];

  executed = false;

  LifeCycleListeners.instance = new LifeCycleListeners;
  SuiteRunner suiteRunner = SuiteRunner("Suite name", tests);

  auto begin = Clock.currTime - 1.msecs;
  suiteRunner.start();
  auto end = Clock.currTime + 1.msecs;

  suiteRunner.result.tests.length.should.equal(1);
  suiteRunner.result.tests[0].begin.should.be.between(begin, end);
  suiteRunner.result.tests[0].end.should.be.between(begin, end);
  suiteRunner.result.tests[0].status.should.be.equal(TestResult.Status.success);
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
  suiteRunner.result.tests[0].status.should.be.equal(TestResult.Status.failure);

  executed.should.equal(true);
}

@("A suite runner should call the suite lifecycle listener methods")
unittest {
  auto beginTime = Clock.currTime - 1.msecs;
  TestCase[string] tests = ["0": TestCase("someTestCase", &mock) ];

  string[] order = [];
  class TestSuiteListener: ISuiteLifecycleListener, ITestCaseLifecycleListener {
    void begin(ref SuiteResult suite) {
      suite.name.should.equal("Suite name");
      suite.begin.should.be.greaterThan(beginTime);
      suite.end.should.be.greaterThan(beginTime);
      suite.tests[0].status.should.equal(TestResult.Status.created);

      order ~= "beginSuite";
    }

    void end(ref SuiteResult suite) {
      suite.name.should.equal("Suite name");
      suite.begin.should.be.greaterThan(beginTime);
      suite.end.should.be.greaterThan(beginTime);
      suite.tests[0].status.should.equal(TestResult.Status.success);

      order ~= "endSuite";
    }

    void begin(ref TestResult test) {
      test.name.should.equal("someTestCase");
      test.begin.should.be.greaterThan(beginTime);
      test.end.should.be.greaterThan(beginTime);
      test.status.should.equal(TestResult.Status.started);

      order ~= "beginTest";
    }

    void end(ref TestResult test) {
      test.name.should.equal("someTestCase");
      test.begin.should.be.greaterThan(beginTime);
      test.end.should.be.greaterThan(beginTime);
      test.status.should.equal(TestResult.Status.success);

      order ~= "endTest";
    }
  }

  SuiteRunner suiteRunner = SuiteRunner("Suite name", tests);
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new TestSuiteListener);

  suiteRunner.start();

  order.should.equal(["beginSuite", "beginTest", "endTest", "endSuite"]);
}

@("A test runner should add the steps to the report")
unittest
{
  auto beginTime = Clock.currTime - 1.msecs;
  auto const test = TestCase("someTestCase", &stepMock);

  LifeCycleListeners.instance = new LifeCycleListeners;
  auto runner = new TestRunner(test);

  auto result = runner.start;

  result.steps.length.should.equal(1);
  result.steps[0].name.should.equal("some step");
  result.steps[0].begin.should.be.greaterThan(beginTime);
  result.steps[0].end.should.be.greaterThan(beginTime);

  result.steps[0].steps.length.should.equal(3);
  result.steps[0].steps.each!(step => step.name.should.startWith("Step "));
}

@("A test runner should call the test listeners in the right order")
unittest
{
  auto const test = TestCase("someTestCase", &stepMock);
  string[] order = [];

  class StepListener : IStepLifecycleListener {
    void begin(ref StepResult step) {
      order ~= "begin " ~ step.name;
    }

    void end(ref StepResult step) {
      order ~= "end " ~ step.name;
    }
  }

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new StepListener);

  new TestRunner(test).start;

  order.should.equal(["begin some step",
                        "begin Step 0", "end Step 0",
                        "begin Step 1", "end Step 1",
                        "begin Step 2", "end Step 2",
                      "end some step"]);
}
