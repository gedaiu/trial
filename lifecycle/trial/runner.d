/++
  The main runner logic. You can find here some LifeCycle logic and test runner
  initalization
  
  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
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
import trial.executor.single;
import trial.executor.parallel;

/// The lifecycle listeners collections. You must use this instance in order
/// to extend the runner. You can have as many listeners as you want. The only restriction
/// is for ITestExecutor, which has no sense to have more than one instance for a run
class LifeCycleListeners {

  /// The global instange.
  static LifeCycleListeners instance;

  private {
    ISuiteLifecycleListener[] suiteListeners;
    ITestCaseLifecycleListener[] testListeners;
    IStepLifecycleListener[] stepListeners;
    ILifecycleListener[] lifecycleListeners;
    ITestExecutor executor = new DefaultExecutor;
  }

  /// Add a listener to the collection
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

  /// send the update event to all listeners
  void update() {
    lifecycleListeners.each!(a => a.update());
  }

  /// send the begin run event to all listeners
  void begin(ulong testCount) {
    lifecycleListeners.each!(a => a.begin(testCount));
  }

  /// send the end runer event to all listeners
  void end(SuiteResult[] result) {
    lifecycleListeners.each!(a => a.end(result));
  }

  /// send the begin suite event to all listeners
  void begin(ref SuiteResult suite) {
    suiteListeners.each!(a => a.begin(suite));
  }

  /// send the end suite event to all listeners
  void end(ref SuiteResult suite) {
    suiteListeners.each!(a => a.end(suite));
  }

  /// send the begin test event to all listeners
  void begin(string suite, ref TestResult test) {
    testListeners.each!(a => a.begin(suite, test));
  }

  /// send the end test event to all listeners
  void end(string suite, ref TestResult test) {
    testListeners.each!(a => a.end(suite, test));
  }


  /// send the begin step event to all listeners
  void begin(string suite, string test, ref StepResult step) {
    stepListeners.each!(a => a.begin(suite, test, step));
  }

  /// send the end step event to all listeners
  void end(string suite, string test, ref StepResult step) {
    stepListeners.each!(a => a.end(suite, test, step));
  }

  /// send the execute test to the executor listener
  SuiteResult[] execute(ref TestCase func) {
    return executor.execute(func);
  }

  /// send the begin execution with the test case list to the executor listener
  SuiteResult[] beginExecution(ref TestCase[] tests) {
    return executor.beginExecution(tests);
  }

  /// send the end execution the executor listener
  SuiteResult[] endExecution() {
    return executor.endExecution();
  }
}

/// setup the LifeCycle collection
void setupLifecycle(Settings settings) {
  LifeCycleListeners.instance = new LifeCycleListeners;
  settings.reporters.map!(a => a.toLower).each!addReporter;

  if(settings.runInParallel) {
    LifeCycleListeners.instance.add(new ParallelExecutor(settings.maxThreads));
  }
}

/// Adds an embeded reporter listener to the LifeCycle listeners collection
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

/// Runs the tests and returns the results
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

/// ditto
auto runTests(TestDiscovery testDiscovery, string testName = "") {
  return runTests(testDiscovery.testCases.values.map!(a => a.values).joiner.array, testName);
}
