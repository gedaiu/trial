module tests.trial.executors.parallel;


import trial.executor.parallel;
import trial.runner;

import core.thread;
import std.datetime;
import std.conv;

import fluent.asserts;
import trial.step;

__gshared bool executed;

void failMock() @system {
  assert(false);
}

void stepMock1() @system {
  Thread.sleep(100.msecs);
  auto a = Step("some step");
  executed = true;
}

void stepMock2() @system {
  Thread.sleep(200.msecs);
  auto a = Step("some step");
  executed = true;
}

void stepMock3() @system {
  Thread.sleep(120.msecs);
  auto a = Step("some step");
  executed = true;

  for(int i=0; i<3; i++) {
    Thread.sleep(120.msecs);
    stepFunction(i);
    Thread.sleep(120.msecs);
  }
}

void stepFunction(int i) {
  Step("Step " ~ i.to!string);
}

@("A parallel executor should get the result of a success test")
unittest
{
  TestCase[] tests = [ TestCase("suite1", "test1", &stepMock1)];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new ParallelExecutor);

  auto begin = Clock.currTime;
  auto result = tests.runTests;

  result.length.should.equal(1);
  result[0].name.should.equal("suite1");

  result[0].tests.length.should.equal(1);
  result[0].tests.length.should.equal(1);
  result[0].tests[0].status.should.equal(TestResult.Status.success);
  (result[0].tests[0].throwable is null).should.equal(true);
}

@("A parallel executor should get the result of a failing test")
unittest
{
  TestCase[] tests = [ TestCase("suite1", "test1", &failMock)];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new ParallelExecutor);

  auto begin = Clock.currTime;
  auto result = tests.runTests;

  result.length.should.equal(1);
  result[0].name.should.equal("suite1");

  result[0].tests.length.should.equal(1);
  result[0].tests.length.should.equal(1);
  result[0].tests[0].status.should.equal(TestResult.Status.failure);
  (result[0].tests[0].throwable !is null).should.equal(true);
}

@("it should call update() many times")
unittest
{
  ulong updated = 0;

  class MockListener : ILifecycleListener {
    void begin(ulong) {}
    void update() { updated++; }
    void end(SuiteResult[]) {}
  }

  TestCase[] tests = [ TestCase("suite2", "test1", &stepMock1) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;

  LifeCycleListeners.instance.add(new MockListener);
  LifeCycleListeners.instance.add(new ParallelExecutor);

  auto results = tests.runTests;

  updated.should.be.greaterThan(50);
}

@("it should run the tests in parallel")
unittest
{
  TestCase[] tests = [ TestCase("suite2", "test1", &stepMock1), TestCase("suite2", "test3", &stepMock1), TestCase("suite2", "test2", &stepMock1) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new ParallelExecutor);

  auto results = tests.runTests;

  results.length.should.equal(1);
  results[0].tests.length.should.equal(3);

  (results[0].end - results[0].begin).should.be.between(90.msecs, 120.msecs);
}

@("it should be able to limit the parallel tests number")
unittest
{
  TestCase[] tests = [ 
    TestCase("suite2", "test1", &stepMock1), 
    TestCase("suite2", "test3", &stepMock1), 
    TestCase("suite2", "test2", &stepMock1) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;

  LifeCycleListeners.instance.add(new ParallelExecutor(2));

  auto results = tests.runTests;

  results.length.should.equal(1);
  results[0].tests.length.should.equal(3);

  (results[0].end - results[0].begin).should.be.between(200.msecs, 250.msecs);
}

@("A parallel executor should call the events in the right order")
unittest
{
  import core.thread;

  executed = false;
  string[] steps;
  class MockListener : IStepLifecycleListener, ITestCaseLifecycleListener, ISuiteLifecycleListener {
      void begin(string suite, string test, ref StepResult step) {
        steps ~= [ suite ~ "." ~ test ~ ".stepBegin " ~ step.name ];
      }

      void end(string suite, string test, ref StepResult step) {
        steps ~= [ suite ~ "." ~ test ~ ".stepEnd " ~ step.name ];
      }

      void begin(string suite, ref TestResult test) {
        steps ~= [ suite ~ ".testBegin " ~ test.name ];
      }

      void end(string suite, ref TestResult test) {
        steps ~= [ suite ~ ".testEnd " ~ test.name ];
      }

      void begin(ref SuiteResult suite) {
        steps ~= [ "begin " ~ suite.name ];
      }

      void end(ref SuiteResult suite) {
        steps ~= [ "end " ~ suite.name ];
      }
  }

  TestCase[] tests = [ TestCase("suite1", "test1", &stepMock1), TestCase("suite2","test2", &stepMock2) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;

  LifeCycleListeners.instance.add(new MockListener);
  LifeCycleListeners.instance.add(new ParallelExecutor);

  auto results = tests.runTests;

  executed.should.equal(true);

  steps.should.contain(["begin suite1", "suite1.testBegin test1", "begin suite2", "suite2.testBegin test2", "suite1.test1.stepBegin some step", "suite1.test1.stepEnd some step", "suite2.test2.stepBegin some step", "suite2.test2.stepEnd some step", "suite1.testEnd test1", "suite2.testEnd test2", "end suite2", "end suite1"]);
}