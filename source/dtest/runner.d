module dtest.runner;

import std.stdio;
import std.algorithm;
import std.datetime;
import std.range;
import std.traits;

import dtest.discovery;
import dtest.interfaces;

struct LifeCycleListeners {
  private {
    ISuiteLifecycleListener[] suiteListeners;
    ITestCaseLifecycleListener[] testListeners;
  }

  void add(T)(T listener) {

    static if(!is(CommonType!(ISuiteLifecycleListener, T) == void)) {
      suiteListeners ~= listener;
    }

    static if(!is(CommonType!(ITestCaseLifecycleListener, T) == void)) {
      testListeners ~= listener;
    }
  }

  void begin(ref SuiteResult suite) {
    suiteListeners.each!(a => a.begin(suite));
  }

  void end(ref SuiteResult suite) {
    suiteListeners.each!(a => a.end(suite));
  }

  void begin(ref TestResult test) {
    testListeners.each!(a => a.begin(test));
  }

  void end(ref TestResult test) {
    testListeners.each!(a => a.end(test));
  }
}

struct SuiteRunner {
  SuiteResult result;

  private {
    TestCase[] tests;
  }

  LifeCycleListeners listeners;

  this(string name, TestCase[string] testCases) {
    result.name = name;

    tests = testCases.values;
    result.tests = tests.map!(a => new TestResult(a.name)).array;
  }

  void start() {
    result.begin = Clock.currTime;
    result.end = Clock.currTime;

    listeners.begin(result);

    tests
      .map!(a => TestRunner(a, listeners))
      .map!(a => a.start)
      .enumerate
      .each!(a => result.tests[a[0]] = a[1]);

    result.end = Clock.currTime;

    listeners.end(result);
  }
}

struct TestRunner {

  private {
    const TestCase testCase;
    LifeCycleListeners listeners;
  }

  static StepResult currentStep;

  this(const TestCase testCase, LifeCycleListeners listeners) {
    this.testCase = testCase;
    this.listeners = listeners;
  }

  static void beginStep(string name) {
    auto step = new StepResult();

    step.name = name;
    step.begin = Clock.currTime;
    step.end = Clock.currTime;

    currentStep.steps ~= step;
  }

  static void endStep() {
    currentStep.steps[currentStep.steps.length - 1].end = Clock.currTime;
  }

  TestResult start() {
    auto test = new TestResult(testCase.name);

    test.begin = Clock.currTime;
    test.end = Clock.currTime;
    test.status = TestResult.Status.started;

    currentStep = test;

    listeners.begin(test);
    try {
      testCase.func();
      test.status = TestResult.Status.success;
    } catch(Throwable t) {
      test.status = TestResult.Status.failure;
      test.throwable = t;
    }

    test.end = Clock.currTime;

    listeners.end(test);
    return test;
  }
}

void runTests(TestDiscovery testDiscovery) {

  foreach(string moduleName, testCases; testDiscovery.testCases) {
    moduleName.writeln;

    foreach(string key, testCase; testCases) {
      testCase.name.writeln;

      try {
          testCase.func();
      } catch(Throwable t) {
          t.writeln;
      }
    }
  }
}
