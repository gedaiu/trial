module tests.trial.interfaces;

import trial.interfaces;


import std.stdio;
import std.conv;
import std.algorithm;
import core.thread;
import std.datetime;

import trial.step;
import trial.runner;
import fluent.asserts;
import trial.executor.single;

__gshared bool executed;

void mock() @system {
  executed = true;
}

void failureMock() @system
{
  executed = true;
  assert(false);
}

void stepFunction(int i)
{
  Step("Step " ~ i.to!string);
}

void stepMock() @system
{
  auto a = Step("some step");
  executed = true;

  for (int i; i < 3; i++)
  {
    stepFunction(i);
  }
}

/// Convert a test case to test result
unittest {
  auto testCase = TestCase("Suite name", "test name", &stepMock, [ Label("label", "value") ]);
  auto testResult = testCase.toTestResult;

  testResult.name.should.equal("test name");
  testResult.labels.should.equal([ Label("label", "value") ]);
  testResult.begin.should.be.greaterThan(Clock.currTime - 1.seconds);
  testResult.end.should.be.greaterThan(Clock.currTime - 1.seconds);
  testResult.status.should.equal(TestResult.Status.created);
}

@("A suite runner should run a success test case and add it to the result")
unittest
{
  TestCase[] tests = [TestCase("Suite name1", "someTestCase", &mock)];

  executed = false;

  auto old = LifeCycleListeners.instance;
  scope (exit)
    LifeCycleListeners.instance = old;

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);

  auto begin = Clock.currTime - 1.msecs;
  auto result = tests.runTests;
  auto end = Clock.currTime + 1.msecs;

  result.length.should.equal(1);
  result[0].tests.length.should.equal(1);
  result[0].tests[0].begin.should.be.between(begin, end);
  result[0].tests[0].end.should.be.between(begin, end);
  result[0].tests[0].status.should.be.equal(TestResult.Status.success);
  executed.should.equal(true);
}

@("A suite runner should run a failing test case and add it to the result")
unittest
{
  TestCase[] tests = [TestCase("Suite name2", "someTestCase", &failureMock)];

  executed = false;
  auto old = LifeCycleListeners.instance;
  scope (exit)
    LifeCycleListeners.instance = old;

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);

  auto begin = Clock.currTime - 1.msecs;
  auto result = tests.runTests;
  auto end = Clock.currTime + 1.msecs;

  result.length.should.equal(1);
  result[0].tests.length.should.equal(1);
  result[0].tests[0].begin.should.be.between(begin, end);
  result[0].tests[0].end.should.be.between(begin, end);
  result[0].tests[0].status.should.be.equal(TestResult.Status.failure);

  executed.should.equal(true);
}

@("A suite runner should call the suite lifecycle listener methods")
unittest
{
  auto old = LifeCycleListeners.instance;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);
  scope (exit)
    LifeCycleListeners.instance = old;

  auto beginTime = Clock.currTime - 1.msecs;
  TestCase[] tests = [TestCase("Suite name", "someTestCase", &mock)];

  string[] order = [];
  class TestSuiteListener : ISuiteLifecycleListener, ITestCaseLifecycleListener
  {
    void begin(ref SuiteResult suite)
    {
      suite.name.should.equal("Suite name");
      suite.begin.should.be.greaterThan(beginTime);
      suite.end.should.be.greaterThan(beginTime);

      suite.tests.length.should.equal(0);

      order ~= "beginSuite";
    }

    void end(ref SuiteResult suite)
    {
      suite.name.should.equal("Suite name");
      suite.begin.should.be.greaterThan(beginTime);
      suite.end.should.be.greaterThan(beginTime);
      suite.tests[0].status.should.equal(TestResult.Status.success);

      order ~= "endSuite";
    }

    void begin(string suite, ref TestResult test)
    {
      test.name.should.equal("someTestCase");
      test.begin.should.be.greaterThan(beginTime);
      test.end.should.be.greaterThan(beginTime);
      test.status.should.equal(TestResult.Status.started);

      order ~= "beginTest";
    }

    void end(string suite, ref TestResult test)
    {
      test.name.should.equal("someTestCase");
      test.begin.should.be.greaterThan(beginTime);
      test.end.should.be.greaterThan(beginTime);
      test.status.should.equal(TestResult.Status.success);

      order ~= "endTest";
    }
  }

  LifeCycleListeners.instance.add(new TestSuiteListener);

  tests.runTests;

  order.should.equal(["beginSuite", "beginTest", "endTest", "endSuite"]);
}

@("A test runner should add the steps to the report")
unittest
{
  auto beginTime = Clock.currTime - 1.msecs;
  auto const test = TestCase("Suite name", "someTestCase", &stepMock);

  auto old = LifeCycleListeners.instance;
  scope (exit)
  {
    LifeCycleListeners.instance = old;
  }

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);

  auto result = [ test ].runTests;

  result[0].tests[0].steps.length.should.equal(1);
  result[0].tests[0].steps[0].name.should.equal("some step");
  result[0].tests[0].steps[0].begin.should.be.greaterThan(beginTime);
  result[0].tests[0].steps[0].end.should.be.greaterThan(beginTime);

  result[0].tests[0].steps[0].steps.length.should.equal(3);
  result[0].tests[0].steps[0].steps.each!(step => step.name.should.startWith("Step "));
}

@("A test runner should call the test listeners in the right order")
unittest
{
  auto const test = TestCase("Suite name", "someTestCase", &stepMock);
  string[] order = [];

  class StepListener : IStepLifecycleListener
  {
    void begin(string suite, string test, ref StepResult step)
    {
      order ~= "begin " ~ step.name;
    }

    void end(string suite, string test, ref StepResult step)
    {
      order ~= "end " ~ step.name;
    }
  }

  auto old = LifeCycleListeners.instance;
  scope (exit)
    LifeCycleListeners.instance = old;

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);
  LifeCycleListeners.instance.add(new StepListener);

  auto result = [test].runTests;

  order.should.equal(["begin some step", "begin Step 0", "end Step 0",
      "begin Step 1", "end Step 1", "begin Step 2", "end Step 2", "end some step"]);
}

@("A suite runner should set the data to an empty suite runner")
unittest
{
  TestCase[] tests;
  auto old = LifeCycleListeners.instance;
  scope (exit)
    LifeCycleListeners.instance = old;

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);

  auto result = tests.runTests();

  result.length.should.equal(0);
}
