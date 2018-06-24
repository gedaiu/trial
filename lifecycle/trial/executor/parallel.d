/++
  A module containing the parallel test runner

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.executor.parallel;

public import trial.interfaces;

import std.datetime;
import std.exception;
import std.algorithm;
import std.array;
import core.thread;

version(unittest) {
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
}
/// The Lifecycle listener used to send data from the tests threads to
/// the main thread
class ThreadLifeCycleListener : LifeCycleListeners {
  static string currentTest;

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

    SuiteResult[] execute(ref const(TestCase)) {
      assert(false, "You can not call `execute` outside of the main thread");
    }

    SuiteResult[] beginExecution(ref const(TestCase)[]) {
      assert(false, "You can not call `beginExecution` outside of the main thread");
    }

    SuiteResult[] endExecution() {
      assert(false, "You can not call `endExecution` outside of the main thread");
    }
  }
}

static ~this() {
  if(ThreadLifeCycleListener.currentTest != "") {
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
        string[] beginTests;
        string[] endTests;
        StepAction[] steps;
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

private void testThreadSetup(string testName) {
  ThreadLifeCycleListener.currentTest = testName;
  LifeCycleListeners.instance = new ThreadLifeCycleListener;
  ThreadProxy.instance.begin(testName);
}

/// The parallel executors runs tests in a sepparate thread
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

  SuiteResult[] execute(ref const(TestCase) testCase) {
    import std.parallelism;

    SuiteResult[] result;

    auto key = testCase.suiteName ~ "|" ~ testCase.name;
    testCases[key] = TestCase(testCase);

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

  SuiteResult[] beginExecution(ref const(TestCase)[] tests) {
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
