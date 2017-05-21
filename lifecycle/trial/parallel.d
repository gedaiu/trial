module trial.parallel;

import trial.interfaces;
import trial.discovery;
import trial.runner;
import std.datetime;
import std.exception;
import std.algorithm;
import std.array;
import core.thread;

class ThreadLifeCycleListener : LifeCycleListeners {
  static string currentTest = "unknown";

  override {
    void begin(string suite, string test, ref StepResult step) {
      ThreadProxy.instance.beginStep(currentTest, step.name, step.begin);
    }

    void end(string suite, string test, ref StepResult step) {
      ThreadProxy.instance.endStep(currentTest, step.name, step.end);
    }

    void end(string, ref TestResult test) {
      assert(false, "You can not call `end` outside of the main thread");
    }

    void begin(string, ref TestResult test) {
      assert(false, "You can not call `begin` outside of the main thread");
    }

    void add(T)(T listener) {
      assert(false, "You can not call `add` outside of the main thread");
    }

    void begin(ulong) {
      assert(false, "You can not call `begin` outside of the main thread");
    }

    void end(SuiteResult[] result) {
      assert(false, "You can not call `end` outside of the main thread");
    }

    void begin(ref SuiteResult suite) {
      assert(false, "You can not call `begin` outside of the main thread");
    }

    void end(ref SuiteResult suite) {
      assert(false, "You can not call `end` outside of the main thread");
    }

    SuiteResult[] execute(ref TestCase) {
      assert(false, "You can not call `execute` outside of the main thread");
    }

    SuiteResult[] beginExecution(ref TestCase[]) {
      assert(false, "You can not call `beginExecution` outside of the main thread");
    }

    SuiteResult[] endExecution() {
      assert(false, "You can not call `endExecution` outside of the main thread");
    }
  }
}

static ~this() {
  if(ThreadLifeCycleListener.currentTest != "unknown") {
    ThreadProxy.instance.end(ThreadLifeCycleListener.currentTest);
  }
}

private {
  import core.atomic;

  struct StepAction {
    enum Type {
      begin,
      end
    }

    string test;
    string name;
    SysTime time;
    Type type;
  }

  synchronized class ThreadProxy {
    private shared static ThreadProxy _instance = new shared ThreadProxy;

    shared {
      private {
        string beginTests[];
        string endTests[];
        StepAction steps[];
        Throwable[string] failures;
        ulong testCount;
      }

      static {
        shared(ThreadProxy) instance() {
          return _instance;
        }
      }

      void reset() {
        beginTests = [];
        endTests = [];
        steps = [];

        failures.clear;
        failures.rehash;

        testCount = 0;
      }

      void begin(string name) {
        beginTests ~= name;
      }

      void end(string name) {
        core.atomic.atomicOp!"+="(this.testCount, 1);
        endTests ~= name;
      }

      auto getTestCount() {
        return testCount;
      }

      void beginStep(shared(string) testName, string stepName, SysTime begin) {
        steps ~= StepAction(testName, stepName, begin, StepAction.Type.begin);
      }

      void endStep(shared(string) testName, string stepName, SysTime end) {
        steps ~= StepAction(testName, stepName, end, StepAction.Type.end);
      }

      void setFailure(string key, shared(Throwable) t) {
        failures[key] = t;
      }

      auto getStatus() {
        struct Status {
          string[] begin;
          StepAction[] steps;
          string[] end;
          Throwable[string] failures;
          ulong testCount;
        }

        auto status = shared Status(beginTests.dup, steps.dup, endTests.dup, failures, testCount);

        beginTests = [];
        steps = [];
        endTests = [];

        return status;
      }
    }
  }
}

void testThreadSetup(string testName) {
  ThreadLifeCycleListener.currentTest = testName;
  LifeCycleListeners.instance = new ThreadLifeCycleListener;
  ThreadProxy.instance.begin(testName);
}

class ParallelExecutor : ITestExecutor {
  struct SuiteStats {
    SuiteResult result;

    ulong testsFinished;
    bool isDone;
  }

  this(uint maxTestCount = 0) {
    this.maxTestCount = maxTestCount;

    if(this.maxTestCount <= 0) {
      import core.cpuid : threadsPerCPU;
      this.maxTestCount = threadsPerCPU;
    }
  }

  private {
    ulong testCount;
    uint maxTestCount;
    string currentSuite = "";

    SuiteStats[string] suiteStats;
    TestCase[string] testCases;

    StepResult[][string] stepStack;

    void addSuiteResult(string name) {
      suiteStats[name].result.begin = Clock.currTime;
      suiteStats[name].result.end = Clock.currTime;

      LifeCycleListeners.instance.begin(suiteStats[name].result);
    }

    void endSuiteResult(string name) {
      suiteStats[name].result.end = Clock.currTime;
      suiteStats[name].isDone = true;

      LifeCycleListeners.instance.end(suiteStats[name].result);
    }

    void addTestResult(string key) {
      auto testCase = testCases[key];

      if(currentSuite != testCase.suiteName) {
        addSuiteResult(testCase.suiteName);
        currentSuite = testCase.suiteName;
      }

      auto testResult = suiteStats[testCase.suiteName]
        .result
        .tests
        .filter!(a => a.name == testCase.name)
          .front;

      testResult.begin = Clock.currTime;
      testResult.end = Clock.currTime;
      testResult.status = TestResult.Status.started;

      LifeCycleListeners.instance.begin(testCase.suiteName, testResult);
      stepStack[key] = [ testResult ];
    }

    void endTestResult(string key, Throwable t) {
      auto testCase = testCases[key];

      auto testResult = suiteStats[testCase.suiteName]
        .result
        .tests
        .filter!(a => a.name == testCase.name)
          .front;

      testResult.end = Clock.currTime;
      testResult.status = t is null ? TestResult.Status.success : TestResult.Status.failure;
      testResult.throwable = t;

      suiteStats[testCases[key].suiteName].testsFinished++;

      LifeCycleListeners.instance.end(testCases[key].suiteName, testResult);
      stepStack.remove(key);
    }

    void addStep(string key, string name, SysTime time) {
      auto step = new StepResult;
      step.name = name;
      step.begin = time;
      step.end = time;

      stepStack[key][stepStack[key].length - 1].steps ~= step;
      stepStack[key] ~= step;

      LifeCycleListeners.instance.begin(testCases[key].suiteName, testCases[key].name, step);
    }

    void endStep(string key, string name, SysTime time) {
      auto step = stepStack[key][stepStack[key].length - 1];

      enforce(step.name == name, "unexpected step name");
      step.end = time;
      stepStack[key] ~= stepStack[key][0..$-1];

      LifeCycleListeners.instance.end(testCases[key].suiteName, testCases[key].name, step);
    }

    auto processEvents() {
      LifeCycleListeners.instance.update;

      auto status = ThreadProxy.instance.getStatus;

      foreach(beginKey; status.begin) {
        addTestResult(beginKey);
      }

      foreach(step; status.steps) {
        if(step.type == StepAction.Type.begin) {
          addStep(step.test, step.name, step.time);
        }

        if(step.type == StepAction.Type.end) {
          endStep(step.test, step.name, step.time);
        }
      }

      foreach(endKey; status.end) {
        Throwable failure = null;

        if(endKey in status.failures) {
          failure = cast() status.failures[endKey];
        }

        endTestResult(endKey, failure);
      }

      foreach(ref index, ref stat; suiteStats.values) {
        if(!stat.isDone && stat.result.tests.length == stat.testsFinished) {
          endSuiteResult(stat.result.name);
        }
      }

      return status.testCount;
    }

    void wait() {
      ulong executedTestCount;

      do {
        LifeCycleListeners.instance.update();
        executedTestCount = processEvents;
        Thread.sleep(1.msecs);
      } while(executedTestCount < testCount);
    }
  }

  SuiteResult[] execute(ref TestCase testCase) {
    import std.parallelism;

    SuiteResult[] result;

    auto key = testCase.suiteName ~ "|" ~ testCase.name;
    testCases[key] = testCase;

    testCount++;

    task({
      testThreadSetup(key);

      try {
        testCase.func();
      } catch(Throwable t) {
        ThreadProxy.instance.setFailure(key, cast(shared)t);
      }
    }).executeInNewThread();

    auto runningTests = testCount - ThreadProxy.instance.getTestCount;

    while(maxTestCount <= runningTests && runningTests > 0) {
      processEvents;
      runningTests = testCount - ThreadProxy.instance.getTestCount;
    }

    return result;
  }

  SuiteResult[] beginExecution(ref TestCase[] tests) {
    foreach(test; tests) {
      auto const suite = test.suiteName;
      if(suite !in suiteStats) {
        suiteStats[suite] = SuiteStats(SuiteResult(suite));
      }

      suiteStats[suite].result.tests ~= new TestResult(test.name);
    }

    ThreadProxy.instance.reset();
    return [];
  }

  SuiteResult[] endExecution() {
    wait;

    foreach(stat; suiteStats.values) {
      if(!stat.isDone) {
        endSuiteResult(stat.result.name);
      }
    }

    SuiteResult[] results;

    foreach(stat; suiteStats) {
      results ~= stat.result;
    }

    return results;
  }
}

version(unittest) {
  import fluent.asserts;
  import trial.step;

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

  (results[0].end - results[0].begin).should.be.between(100.msecs, 120.msecs);
}

@("it should be able to limit the parallel tests number")
unittest
{
  TestCase[] tests = [ TestCase("suite2", "test1", &stepMock1), TestCase("suite2", "test3", &stepMock1), TestCase("suite2", "test2", &stepMock1) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;

  LifeCycleListeners.instance.add(new ParallelExecutor(2));

  auto results = tests.runTests;

  results.length.should.equal(1);
  results[0].tests.length.should.equal(3);

  (results[0].end - results[0].begin).should.be.between(200.msecs, 220.msecs);
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
