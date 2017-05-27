module trial.executor.single;

import trial.interfaces;
import trial.runner;
import std.datetime;
import trial.stackresult;
import trial.step;

/**
The default test executor runs test in sequential order in a single thread
*/
class DefaultExecutor : ITestExecutor, IStepLifecycleListener
{
  private
  {
    SuiteResult suiteResult;
    TestResult testResult;
    StepResult currentStep;
    StepResult[] stepStack;
  }

  /// Add the step result and update the other listeners on every step
  void begin(string suite, string test, ref StepResult step)
  {
    currentStep.steps ~= step;
    stepStack ~= currentStep;
    currentStep = step;
    LifeCycleListeners.instance.update();
  }

  /// Update the other listeners on every step
  void end(string suite, string test, ref StepResult step)
  {
    currentStep = stepStack[stepStack.length - 1];
    stepStack = stepStack[0 .. $-1];
    LifeCycleListeners.instance.update();
  }

  /// It does nothing
  SuiteResult[] beginExecution(ref TestCase[])
  {
    return [];
  }

  /// Return the result for the last executed suite
  SuiteResult[] endExecution()
  {
    if (suiteResult.begin == SysTime.min)
    {
      return [];
    }

    LifeCycleListeners.instance.update();
    LifeCycleListeners.instance.end(suiteResult);
    return [suiteResult];
  }

  private
  {
    void createTestResult(TestCase testCase)
    {
      testResult = new TestResult(testCase.name);
      testResult.begin = Clock.currTime;
      testResult.end = Clock.currTime;
      testResult.status = TestResult.Status.started;
      currentStep = testResult;

      stepStack = [];

      Step.suite = testCase.suiteName;
      Step.test = testCase.name;

      LifeCycleListeners.instance.begin(testCase.suiteName, testResult);

      try
      {
        testCase.func();
        testResult.status = TestResult.Status.success;
      }
      catch (Throwable t)
      {
        testResult.status = TestResult.Status.failure;
        testResult.throwable = t.toTestException;
      }

      testResult.end = Clock.currTime;
      LifeCycleListeners.instance.end(testCase.suiteName, testResult);
    }
  }

  /// Execute a test case
  SuiteResult[] execute(ref TestCase testCase)
  {
    SuiteResult[] result;

    LifeCycleListeners.instance.update();
    if (suiteResult.name != testCase.suiteName)
    {
      if (suiteResult.begin != SysTime.min)
      {
        suiteResult.end = Clock.currTime;
        LifeCycleListeners.instance.end(suiteResult);
        result = [suiteResult];
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

version (is_trial_embeded)
{
  private auto toTestException(Throwable t)
  {
    return t;
  }
}
