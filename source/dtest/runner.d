module dtest.runner;

import std.stdio;
import std.algorithm;
import std.datetime;
import std.range;
import std.traits;

import dtest.discovery;
import dtest.interfaces;

class LifeCycleListeners {
  static LifeCycleListeners instance;

  private {
    ISuiteLifecycleListener[] suiteListeners;
    ITestCaseLifecycleListener[] testListeners;
    IStepLifecycleListener[] stepListeners;
    ILifecycleListener[] lifecycleListeners;
  }

  void add(T)(T listener) {

    static if(!is(CommonType!(ISuiteLifecycleListener, T) == void)) {
      suiteListeners ~= listener;
    }

    static if(!is(CommonType!(ITestCaseLifecycleListener, T) == void)) {
      testListeners ~= listener;
    }

    static if(!is(CommonType!(IStepLifecycleListener, T) == void)) {
      stepListeners ~= listener;
    }

    static if(!is(CommonType!(ILifecycleListener, T) == void)) {
      lifecycleListeners ~= listener;
    }
  }

  void begin() {
    lifecycleListeners.each!(a => a.begin());
  }

  void end(SuiteResult[] result) {
    lifecycleListeners.each!(a => a.end(result));
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

  void begin(ref StepResult step) {
    stepListeners.each!(a => a.begin(step));
  }

  void end(ref StepResult step) {
    stepListeners.each!(a => a.end(step));
  }
}

struct SuiteRunner {
  SuiteResult result;

  private {
    TestCase[] tests;
  }

  this(string name, TestCase[string] testCases) {
    result.name = name;

    tests = testCases.values;
    result.tests = tests.map!(a => new TestResult(a.name)).array;
  }

  void start() {
    result.begin = Clock.currTime;
    result.end = Clock.currTime;
 
    LifeCycleListeners.instance.begin(result);

    tests
      .map!(a => new TestRunner(a))
      .map!(a => a.start)
      .enumerate
      .each!(a => result.tests[a[0]] = a[1]);

    result.end = Clock.currTime;

    LifeCycleListeners.instance.end(result);
  }
}

class TestRunner {

  static TestRunner instance;

  private {
    const TestCase testCase;
    StepResult[] stepStack;
  }

  this(const TestCase testCase) {
    this.testCase = testCase;
  }

  void beginStep(string name) {
    auto step = new StepResult();

    step.name = name;
    step.begin = Clock.currTime;
    step.end = Clock.currTime;

    stepStack[0].steps ~= step;
    stepStack = step ~ stepStack;

    LifeCycleListeners.instance.begin(step);
  }

  void endStep() {
    const size_t last = stepStack[0].steps.length - 1;
    stepStack[0].end = Clock.currTime;
    auto step = stepStack[0];

    stepStack = stepStack[1..$];

    LifeCycleListeners.instance.end(step);
  }

  TestResult start() {
    instance = this;
    auto test = new TestResult(testCase.name);

    test.begin = Clock.currTime;
    test.end = Clock.currTime;
    test.status = TestResult.Status.started;

    stepStack = [ test ];

    LifeCycleListeners.instance.begin(test);
    try {
      testCase.func();
      test.status = TestResult.Status.success;
    } catch(Throwable t) {
      test.status = TestResult.Status.failure;
      test.throwable = t;
    }

    test.end = Clock.currTime;

    LifeCycleListeners.instance.end(test);

    return test;
  }
}

void runTests(TestDiscovery testDiscovery) {
  import dtest.reporters.spec;
  import dtest.reporters.result;

  LifeCycleListeners.instance = new LifeCycleListeners;

  LifeCycleListeners.instance.add(new SpecReporter);
  LifeCycleListeners.instance.add(new ResultReporter);

  LifeCycleListeners.instance.begin;

  SuiteResult[] results = [];

  foreach(string moduleName, testCases; testDiscovery.testCases) {
    auto suiteRunner = SuiteRunner(moduleName, testCases);
    suiteRunner.start;

    results ~= suiteRunner.result;
  }

  LifeCycleListeners.instance.end(results);
}
