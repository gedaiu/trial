module tests.trial.executors.parallel;


import trial.executor.parallel;
import trial.runner;

import core.thread;
import std.datetime;
import std.conv;

import fluent.asserts;
import trial.step;
import trial.interfaces : PendingTestException;

__gshared bool executed;

void failMock() @system {
  assert(false);
}

void pendingMock() @system {
  throw new PendingTestException();
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

void nestedParallelRunMock() @system {
  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new ParallelExecutor);

  [ TestCase("inner", "test", &stepMock1) ].runTests;
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
  result[0].tests[0].status.should.equal(TestResult.Status.failure);
  (result[0].tests[0].throwable !is null).should.equal(true);
}

@("A parallel executor reports a pending test as pending")
unittest
{
  TestCase[] tests = [ TestCase("suite1", "test1", &pendingMock)];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new ParallelExecutor);

  auto result = tests.runTests;

  result[0].tests[0].status.should.equal(TestResult.Status.pending);
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

@("A parallel executor with three threads runs three 100ms tests in under 200ms")
unittest
{
  TestCase[] tests = [ TestCase("suite2", "test1", &stepMock1), TestCase("suite2", "test3", &stepMock1), TestCase("suite2", "test2", &stepMock1) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new ParallelExecutor(3));

  auto results = tests.runTests;

  results.length.should.equal(1);
  results[0].tests.length.should.equal(3);

  (results[0].end - results[0].begin).should.be.between(90.msecs, 200.msecs);
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

@("A parallel executor completes a test that runs its own parallel executor")
unittest
{
  TestCase[] tests = [ TestCase("outer", "test", &nestedParallelRunMock) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new ParallelExecutor);

  auto result = tests.runTests;

  result[0].tests[0].status.should.equal(TestResult.Status.success);
}

__gshared ThreadID[] threadIds;
__gshared Object threadIdsLock;

shared static this() {
  threadIdsLock = new Object;
}

void recordThreadMock() @system {
  synchronized(threadIdsLock) {
    threadIds ~= Thread.getThis.id;
  }
}

@("A parallel executor with one thread runs every test on the same worker thread")
unittest
{
  import std.algorithm : sort, uniq;
  import std.array : array;

  threadIds = [];

  TestCase[] tests = [
    TestCase("suite3", "test1", &recordThreadMock),
    TestCase("suite3", "test2", &recordThreadMock),
    TestCase("suite3", "test3", &recordThreadMock) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new ParallelExecutor(1));

  tests.runTests;

  threadIds.sort.uniq.array.length.should.equal(1);
}
