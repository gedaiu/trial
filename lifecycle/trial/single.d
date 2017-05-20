module trial.single;

import trial.interfaces;
import trial.runner;
import std.datetime;
import trial.stackresult;
import trial.step;

class DefaultExecutor : ITestExecutor, IStepLifecycleListener {
  private {
    SuiteResult suiteResult;
    TestResult testResult;
    StepResult[] stepStack;
  }

  void begin(string suite, string test, ref StepResult step) {
    stepStack[stepStack.length - 1].steps ~= step;
    stepStack ~= step;
    LifeCycleListeners.instance.update();
  }

  void end(string suite, string test, ref StepResult step) {
    stepStack = stepStack[0..$-1];
    LifeCycleListeners.instance.update();
  }

  SuiteResult[] beginExecution(ref TestCase[]) {
    return [];
  }

  SuiteResult[] endExecution() {
    if(suiteResult.begin == SysTime.min) {
      return [];
    }

    LifeCycleListeners.instance.update();
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

      Step.suite = testCase.suiteName;
      Step.test = testCase.name;

      LifeCycleListeners.instance.begin(testCase.suiteName, testResult);

      try {
        testCase.func();
        testResult.status = TestResult.Status.success;
      } catch(Throwable t) {
        testResult.status = TestResult.Status.failure;
        testResult.throwable = toTestException(t);
      }

      testResult.end = Clock.currTime;
      LifeCycleListeners.instance.end(testCase.suiteName, testResult);
    }
  }

  SuiteResult[] execute(ref TestCase testCase) {
    SuiteResult[] result;

    LifeCycleListeners.instance.update();
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
    LifeCycleListeners.instance.update();

    return result;
  }
}

version(is_trial_embeded) {
  auto toTestException(Throwable t) {
    return t;
  }
}
