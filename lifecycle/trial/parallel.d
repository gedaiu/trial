module trial.parallel;

import trial.interfaces;
import trial.discovery;
import trial.runner;
import std.datetime;
import std.exception;

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

    void begin() {
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

    SuiteResult[] execute(TestCase func) {
      assert(false, "You can not call `execute` outside of the main thread");
    }

    SuiteResult[] beginExecution() {
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
        ulong testCount;
      }

      static {
        shared(ThreadProxy) instance() {
          return _instance;
        }
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

      auto getStatus() {
        struct Status {
          string[] begin;
          StepAction[] steps;
          string[] end;
          ulong testCount;
        }

        auto status = shared Status(beginTests.dup, steps.dup, endTests.dup, testCount);

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

    ulong testCount;
    ulong testsFinished;
    bool isDone;
  }

  private {
    ulong testCount;

    SuiteStats[string] suiteStats;
    TestCase[string] testCases;

    TestResult[string] testResults;
    StepResult[][string] stepStack;

    void addSuiteResult(string name) {
      suiteStats[name] = SuiteStats();
      suiteStats[name].result.name = name;
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

      if(testCase.suiteName !in suiteStats) {
        addSuiteResult(testCase.suiteName);
      }

      auto testResult = new TestResult(testCase.name);
      testResult.begin = Clock.currTime;
      testResult.end = Clock.currTime;
      testResult.status = TestResult.Status.started;

      LifeCycleListeners.instance.begin(testCase.suiteName, testResult);
      testResults[key] = testResult;
      stepStack[key] = [ testResult ];
    }

    void endTestResult(string key) {
      auto testResult = testResults[key];
      testResult.end = Clock.currTime;

      LifeCycleListeners.instance.end(testCases[key].suiteName, testResult);
      testResults.remove(key);
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

    void wait() {
      ulong executedTestCount;

      do {
        auto status = ThreadProxy.instance.getStatus;
        executedTestCount = status.testCount;

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
          endTestResult(endKey);
        }

        Thread.sleep(1.msecs);
      } while(executedTestCount < testCount);
    }
  }

  SuiteResult[] execute(TestCase testCase) {
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
      }
    }).executeInNewThread();

    return result;
  }

  SuiteResult[] beginExecution() {
    return [];
  }

  SuiteResult[] endExecution() {
    wait;

    foreach(stat; suiteStats.byValue) {
      if(!stat.isDone) {
        endSuiteResult(stat.result.name);
      }
    }

    return [];
  }
}

version(unittest) {
  import fluent.asserts;
  import core.thread;
  import trial.step;

  void stepMock1() @system {
    Thread.sleep(100.msecs);
    auto a = Step("some step");
    executed = true;
  }

  void stepMock2() @system {
    Thread.sleep(120.msecs);
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

  TestCase[] tests = [ TestCase("suite1", "test1", &stepMock1), TestCase("suite1","test2", &stepMock2) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) LifeCycleListeners.instance = old;
  LifeCycleListeners.instance = new LifeCycleListeners;

  LifeCycleListeners.instance.add(new MockListener);
  LifeCycleListeners.instance.add(new ParallelExecutor);

  tests.runTests;

  executed.should.equal(true);
  steps.should.equal(["begin suite1",
  "suite1.testBegin test1",
  "suite1.testBegin test2",

  "suite1.test1.stepBegin some step",
  "suite1.test1.stepEnd some step",
  "suite1.testEnd test1",

  "suite1.test2.stepBegin some step",
  "suite1.test2.stepEnd some step",
  "suite1.testEnd test2",

  "end suite1"]);
}
