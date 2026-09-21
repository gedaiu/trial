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
import core.thread;
import std.parallelism;

version(unittest) {
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
}
/// The Lifecycle listener used to send data from the tests threads to
/// the main thread
class ThreadLifeCycleListener : LifeCycleListeners {
  static string currentTest;

  // Unshared on purpose: a `shared` static is one process-wide global, so a nested
  // executor's worker would overwrite the outer test's proxy. Unshared keeps it per thread.
  static ThreadProxy currentProxy;

  /// The proxy of the executor that runs the current thread's test
  static shared(ThreadProxy) proxy() {
    return cast(shared) currentProxy;
  }

  /// proxy returns the proxy stored for the current thread
  unittest {
    auto old = currentProxy;
    scope(exit) currentProxy = old;

    auto expected = new shared ThreadProxy;
    currentProxy = cast() expected;

    (proxy is expected).should.equal(true);
  }

  override {
    void begin(string suite, string test, ref StepResult step) {
      proxy.beginStep(currentTest, step.name, step.begin);
    }

    void end(string suite, string test, ref StepResult step) {
      proxy.endStep(currentTest, step.name, step.end);
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

private {
  import core.atomic;

  struct TestBegin {
    string test;
    SysTime time;
  }

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
    shared {
      private {
        TestBegin[] beginTests;
        string[] endTests;
        StepAction[] steps;
        Throwable[string] failures;
        ulong testCount;
      }

      void reset() {
        beginTests = [];
        endTests = [];
        steps = [];

        failures = typeof(failures).init;

        testCount = 0;
      }

      void begin(string name) {
        beginTests ~= TestBegin(name, Clock.currTime);
      }

      void end(string name) {
        core.atomic.atomicOp!"+="(this.testCount, 1);
        endTests ~= name;
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
          TestBegin[] begin;
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

private void testThreadSetup(string testName, shared(ThreadProxy) proxy) {
  ThreadLifeCycleListener.currentTest = testName;
  ThreadLifeCycleListener.currentProxy = cast() proxy;
  LifeCycleListeners.instance = new ThreadLifeCycleListener;
  proxy.begin(testName);
}

/// Runs a test on the current worker thread and reports its begin, failure and end to the proxy
void runTestOnWorker(string key, TestCaseDelegate func, shared(ThreadProxy) proxy) {
  testThreadSetup(key, proxy);

  scope(exit) {
    proxy.end(key);
    ThreadLifeCycleListener.currentTest = "";
  }

  try {
    func();
  } catch(Throwable t) {
    proxy.setFailure(key, cast(shared) t);
  }
}

/// runTestOnWorker reports one begin, one end and the failure of a throwing test
unittest {
  auto oldListeners = LifeCycleListeners.instance;
  auto oldProxy = ThreadLifeCycleListener.currentProxy;
  scope(exit) {
    LifeCycleListeners.instance = oldListeners;
    ThreadLifeCycleListener.currentProxy = oldProxy;
  }

  auto proxy = new shared ThreadProxy;
  runTestOnWorker("suite1|test1", delegate() @system { throw new Exception("failed"); }, proxy);

  auto status = proxy.getStatus;

  status.begin.length.should.equal(1);
  (cast(string[]) status.end).should.equal(["suite1|test1"]);
  (cast(Throwable[string]) status.failures).keys.should.equal(["suite1|test1"]);
  ThreadLifeCycleListener.currentTest.should.equal("");
}

/// The first result with the given name inside a suite that has not started yet
TestResult testNamed(ref SuiteResult suite, string name) {
  return suite.tests.filter!(a => a.name == name && a.status == TestResult.Status.created).front;
}

/// testNamed returns the suite test with the matching name
unittest {
  auto suite = SuiteResult("suite1");
  suite.tests = [ new TestResult("test1"), new TestResult("test2") ];

  suite.testNamed("test2").should.equal(suite.tests[1]);
}

/// The parallel executors runs tests in a sepparate thread
class ParallelExecutor : ITestExecutor {
  struct SuiteStats {
    // SuiteResult disables default construction to force a suite name, which
    // would leave SuiteStats non default constructible. Since dmd 2.112 the
    // associative array rewrite instantiates `_aaValues` for every value type
    // and that requires one, so `suiteStats.values` stopped compiling. Naming
    // `.init` here keeps SuiteResult's invariant for every other caller.
    SuiteResult result = SuiteResult.init;

    ulong testsFinished;
    bool isDone;
  }

  this(uint maxTestCount = 0) {
    this.proxy = new shared ThreadProxy;
    this.maxTestCount = maxTestCount;

    if(this.maxTestCount <= 0) {
      import core.cpuid : threadsPerCPU;
      this.maxTestCount = threadsPerCPU;
    }
  }

  private {
    shared ThreadProxy proxy;
    TaskPool pool;
    ulong testCount;
    uint maxTestCount;
    string currentSuite = "";

    SuiteStats[string] suiteStats;
    TestCase[string] testCases;
    TestResult[string] testResults;

    StepResult[][string] stepStack;

    void addSuiteResult(string name, SysTime time) {
      suiteStats[name].result.begin = time;
      suiteStats[name].result.end = Clock.currTime;

      LifeCycleListeners.instance.begin(suiteStats[name].result);
    }

    void endSuiteResult(string name) {
      suiteStats[name].result.end = Clock.currTime;
      suiteStats[name].isDone = true;

      LifeCycleListeners.instance.end(suiteStats[name].result);
    }

    void addTestResult(string key, SysTime time = Clock.currTime) {
      auto testCase = testCases[key];

      if(currentSuite != testCase.suiteName) {
        addSuiteResult(testCase.suiteName, time);
        currentSuite = testCase.suiteName;
      }

      auto testResult = suiteStats[testCase.suiteName].result.testNamed(testCase.name);
      testResults[key] = testResult;

      testResult.begin = time;
      testResult.end = time;
      testResult.status = TestResult.Status.started;

      LifeCycleListeners.instance.begin(testCase.suiteName, testResult);
      stepStack[key] = [ testResult ];
    }

    void endTestResult(string key, Throwable t) {
      auto testCase = testCases[key];

      auto testResult = testResults[key];

      testResult.end = Clock.currTime;
      testResult.status = t.toStatus;

      if (testResult.status == TestResult.Status.failure) {
        testResult.throwable = t;
      }

      suiteStats[testCase.suiteName].testsFinished++;

      LifeCycleListeners.instance.end(testCase.suiteName, testResult);
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
      stepStack[key] = stepStack[key][0..$-1];

      LifeCycleListeners.instance.end(testCases[key].suiteName, testCases[key].name, step);
    }

    auto processEvents() {
      LifeCycleListeners.instance.update;

      auto status = proxy.getStatus;

      foreach(testBegin; status.begin) {
        addTestResult(testBegin.test, testBegin.time);
      }

      foreach(step; status.steps) {
        final switch(step.type) {
          case StepAction.Type.begin:
            addStep(step.test, step.name, step.time);
            break;

          case StepAction.Type.end:
            endStep(step.test, step.name, step.time);
            break;
        }
      }

      foreach(endKey; status.end) {
        Throwable failure = null;

        if(endKey in status.failures) {
          failure = cast() status.failures[endKey];
        }

        endTestResult(endKey, failure);
      }

      foreach(ref stat; suiteStats) {
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
    import std.conv : to;

    auto key = testCount.to!string ~ "|" ~ testCase.suiteName ~ "|" ~ testCase.name;
    testCases[key] = TestCase(testCase);

    testCount++;

    if(pool is null) {
      pool = new TaskPool(maxTestCount);
      pool.isDaemon = true;
    }

    pool.put(task!runTestOnWorker(key, testCase.func, proxy));

    return [];
  }

  SuiteResult[] beginExecution(ref const(TestCase)[] tests) {
    foreach(test; tests) {
      auto const suite = test.suiteName;
      if(suite !in suiteStats) {
        suiteStats[suite] = SuiteStats(SuiteResult(suite));
      }

      suiteStats[suite].result.tests ~= new TestResult(test.name);
    }

    proxy.reset();
    return [];
  }

  SuiteResult[] endExecution() {
    wait;

    if(pool !is null) {
      pool.finish(true);
      pool = null;
    }

    foreach(ref stat; suiteStats) {
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

/// endStep leaves only the test result on the step stack after one step ends
unittest {
  auto old = LifeCycleListeners.instance;
  LifeCycleListeners.instance = new LifeCycleListeners;
  scope (exit) LifeCycleListeners.instance = old;

  auto executor = new ParallelExecutor;
  const(TestCase)[] tests = [TestCase("suite1", "test1", delegate() {})];
  executor.beginExecution(tests);

  auto key = "suite1|test1";
  executor.testCases[key] = TestCase(tests[0]);

  executor.addTestResult(key);
  executor.addStep(key, "some step", Clock.currTime);
  executor.endStep(key, "some step", Clock.currTime);

  executor.stepStack[key].length.should.equal(1);
}
