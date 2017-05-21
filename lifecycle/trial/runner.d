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
import trial.single;
import trial.parallel;

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

  void update() {
    lifecycleListeners.each!(a => a.update());
  }

  void begin(ulong testCount) {
    lifecycleListeners.each!(a => a.begin(testCount));
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

  void begin(string suite, ref TestResult test) {
    testListeners.each!(a => a.begin(suite, test));
  }

  void end(string suite, ref TestResult test) {
    testListeners.each!(a => a.end(suite, test));
  }

  void begin(string suite, string test, ref StepResult step) {
    stepListeners.each!(a => a.begin(suite, test, step));
  }

  void end(string suite, string test, ref StepResult step) {
    stepListeners.each!(a => a.end(suite, test, step));
  }

  SuiteResult[] execute(ref TestCase func) {
    return executor.execute(func);
  }

  SuiteResult[] beginExecution(ref TestCase[] tests) {
    return executor.beginExecution(tests);
  }

  SuiteResult[] endExecution() {
    return executor.endExecution();
  }
}

void setupLifecycle(Settings settings) {
  LifeCycleListeners.instance = new LifeCycleListeners;
  settings.reporters.map!(a => a.toLower).each!addReporter;

  if(settings.runInParallel) {
    LifeCycleListeners.instance.add(new ParallelExecutor(settings.maxThreads));
  }
}

void addReporter(string name) {
    import trial.reporters.spec;
    import trial.reporters.specprogress;
    import trial.reporters.dotmatrix;
    import trial.reporters.landing;
    import trial.reporters.progress;
    import trial.reporters.html;
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

      case "dot-matrix":
        LifeCycleListeners.instance.add(new DotMatrixReporter);
        break;

      case "landing":
        LifeCycleListeners.instance.add(new LandingReporter);
        break;

      case "progress":
        LifeCycleListeners.instance.add(new ProgressReporter);
        break;

      case "html":
        LifeCycleListeners.instance.add(new HtmlReporter);
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

auto runTests(TestCase[] tests, string testName = "") {
  LifeCycleListeners.instance.begin(tests.length);

  SuiteResult[] results = LifeCycleListeners.instance.beginExecution(tests);

  foreach(test; tests.filter!(a => a.name.indexOf(testName) != -1)) {
    results ~= LifeCycleListeners.instance.execute(test);
  }

  results ~= LifeCycleListeners.instance.endExecution;
  LifeCycleListeners.instance.end(results);

  return results;
}

auto runTests(TestDiscovery testDiscovery, string testName = "") {
  return runTests(testDiscovery.testCases.values.map!(a => a.values).joiner.array, testName);
}
