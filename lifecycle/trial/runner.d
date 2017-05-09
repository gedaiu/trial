module trial.runner;

import std.stdio;
import std.algorithm;
import std.datetime;
import std.range;
import std.traits;
import std.string;

import trial.discovery;
import trial.interfaces;
import trial.settings;
import trial.stackresult;

class LifeCycleListeners {
  static LifeCycleListeners instance;

  private {
    ISuiteLifecycleListener[] suiteListeners;
    ITestCaseLifecycleListener[] testListeners;
    IStepLifecycleListener[] stepListeners;
    ILifecycleListener[] lifecycleListeners;
    ITestExecutor executor = new DefaultExecutor;
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

    static if(!is(CommonType!(ITestExecutor, T) == void)) {
      executor = listener;
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

  void execute(TestCaseFunction func) {
    executor.execute(func);
  }
}

class DefaultExecutor : ITestExecutor {
  void execute(TestCaseFunction func) {
    func();
  }
}

class SuiteRunner {
  SuiteResult result;

  private {
    TestCase[] tests;
  }

  this(string name, TestCase[] testCases) {
    result.name = name;

    tests = testCases;
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
    TestCase testCase;
    StepResult[] stepStack;
  }

  this(TestCase testCase) {
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
    auto oldRunnerInstance = instance;
    auto oldListenersInstance = LifeCycleListeners.instance;
    scope(exit) {
      instance = oldRunnerInstance;
      LifeCycleListeners.instance = oldListenersInstance;
    }

    instance = this;
    auto test = new TestResult(testCase.name);

    test.begin = Clock.currTime;
    test.end = Clock.currTime;
    test.status = TestResult.Status.started;

    stepStack = [ test ];

    LifeCycleListeners.instance.begin(test);
    try {
      LifeCycleListeners.instance.execute(testCase.func);
      test.status = TestResult.Status.success;
    } catch(Throwable t) {
      test.status = TestResult.Status.failure;
      test.throwable = toTestException(t);
    }

    test.end = Clock.currTime;

    LifeCycleListeners.instance.end(test);

    return test;
  }
}

void setupLifecycle(Settings settings) {
  LifeCycleListeners.instance = new LifeCycleListeners;

  settings.reporters.map!(a => a.toLower).each!addReporter;
}

void addReporter(string name) {
    import trial.reporters.spec;
    import trial.reporters.specprogress;
    import trial.reporters.stats;
    import trial.reporters.result;

    switch(name) {
      case "spec":
        LifeCycleListeners.instance.add(new SpecReporter);
        break;

      case "spec-progress":
        auto storage = statsFromFile("trial-stats.csv");
        LifeCycleListeners.instance.add(new SpecProgressReporter(storage));
        break;

      case "result":
        LifeCycleListeners.instance.add(new ResultReporter);
        break;

      case "stats":
        LifeCycleListeners.instance.add(new StatsReporter);
        break;

      default:
        writeln("There is no `" ~ name ~"` reporter");
    }
}

void runTests(TestDiscovery testDiscovery, string testName = "") {
  LifeCycleListeners.instance.begin;

  SuiteResult[] results = [];

  foreach(string moduleName, testCases; testDiscovery.testCases) {
    auto tests = testCases.values.filter!(a => a.name.indexOf(testName) != -1).array;

    if(tests.length > 0) {
      auto suiteRunner = new SuiteRunner(moduleName, tests);
      suiteRunner.start;

      results ~= suiteRunner.result;
    }
  }

  LifeCycleListeners.instance.end(results);
}

version(is_trial_embeded) {
  auto toTestException(Throwable t) {
    return t;
  }
}
