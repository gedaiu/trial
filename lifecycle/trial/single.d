module trial.single;

import trial.interfaces;
import trial.runner;
import std.datetime;
import trial.stackresult;

class DefaultExecutor : ITestExecutor, IStepLifecycleListener {
  private {
    SuiteResult suiteResult;
    TestResult testResult;
    StepResult[] stepStack;
  }

  void begin(ref StepResult step) {
    stepStack[stepStack.length - 1].steps ~= step;
    stepStack ~= step;
  }

  void end(ref StepResult step) {
    stepStack = stepStack[0..$-1];
  }

  SuiteResult[] beginExecution() {
    return [];
  }

  SuiteResult[] endExecution() {
    if(suiteResult.begin == SysTime.min) {
      return [];
    }

    LifeCycleListeners.instance.end(suiteResult);
    return [ suiteResult ];
  }

  private {
    void createTestResult(TestCase testCase) {
      testResult = new TestResult(testCase.name);
      testResult.begin = Clock.currTime;
      testResult.end = Clock.currTime;
      testResult.status = TestResult.Status.started;
      stepStack = [ testResult ];

      LifeCycleListeners.instance.begin(testResult);

      try {
        testCase.func();
        testResult.status = TestResult.Status.success;
      } catch(Throwable t) {
        testResult.status = TestResult.Status.failure;
        testResult.throwable = toTestException(t);
      }

      testResult.end = Clock.currTime;
      LifeCycleListeners.instance.end(testResult);
    }
  }

  SuiteResult[] execute(TestCase testCase) {
    SuiteResult[] result;

    if(suiteResult.name != testCase.suiteName) {
      if(suiteResult.begin != SysTime.min) {
        suiteResult.end = Clock.currTime;
        LifeCycleListeners.instance.end(suiteResult);
        result = [ suiteResult ];
      }

      suiteResult = SuiteResult(testCase.suiteName, Clock.currTime, Clock.currTime);
      LifeCycleListeners.instance.begin(suiteResult);
    }

    createTestResult(testCase);
    suiteResult.tests ~= testResult;

    return result;
  }
}

version(is_trial_embeded) {
  auto toTestException(Throwable t) {
    return t;
  }
}
