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

import trial.settings;
import trial.executor.single;
import trial.executor.parallel;

/// setup the LifeCycle collection
void setupLifecycle(Settings settings) {
  LifeCycleListeners.instance = new LifeCycleListeners;
  settings.reporters.map!(a => a.toLower).each!addReporter;

  if(settings.runInParallel) {
    LifeCycleListeners.instance.add(new ParallelExecutor(settings.maxThreads));
  } else {
    LifeCycleListeners.instance.add(new DefaultExecutor);
  }
}

/// Adds an embeded reporter listener to the LifeCycle listeners collection
void addReporter(string name) {
    import trial.reporters.spec;
    import trial.reporters.specprogress;
    import trial.reporters.specsteps;
    import trial.reporters.dotmatrix;
    import trial.reporters.landing;
    import trial.reporters.progress;
    import trial.reporters.list;
    import trial.reporters.html;
    import trial.reporters.allure;
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

      case "spec-steps":
        LifeCycleListeners.instance.add(new SpecStepsReporter);
        break;

      case "dot-matrix":
        LifeCycleListeners.instance.add(new DotMatrixReporter);
        break;

      case "landing":
        LifeCycleListeners.instance.add(new LandingReporter);
        break;

      case "list":
        LifeCycleListeners.instance.add(new ListReporter);
        break;

      case "progress":
        LifeCycleListeners.instance.add(new ProgressReporter);
        break;

      case "html":
        LifeCycleListeners.instance.add(new HtmlReporter);
        break;

      case "allure":
        LifeCycleListeners.instance.add(new AllureReporter);
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
auto runTests(const(TestCase)[] tests, string testName = "") {
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
auto runTests(string testName = "") {
  return runTests(LifeCycleListeners.instance.getTestCases, testName);
}

/// Check if a suite result list is a success
bool isSuccess(SuiteResult[] results) {
  return results.map!(a => a.tests).joiner.map!(a => a.status).all!(a => a == TestResult.Status.success);
}

version(unittest) {
  import fluent.asserts;
}

/// It should return true for an empty result
unittest {
  [].isSuccess.should.equal(true);
}

/// It should return true if all the tests succeded
unittest {
  SuiteResult[] results = [ SuiteResult("") ];
  results[0].tests = [ new TestResult("") ];
  results[0].tests[0].status = TestResult.Status.success;

  results.isSuccess.should.equal(true);
}

/// It should return false if one the tests failed
unittest {
  SuiteResult[] results = [ SuiteResult("") ];
  results[0].tests = [ new TestResult("") ];
  results[0].tests[0].status = TestResult.Status.failure;

  results.isSuccess.should.equal(false);
}

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
    ITestDiscovery[] testDiscoveryListeners;
    IAttachmentListener[] attachmentListeners;
    ITestExecutor executor;
  }

  TestCase[] getTestCases() {
    return testDiscoveryListeners.map!(a => a.getTestCases).join;
  }

  /// Add a listener to the collection
  void add(T)(T listener) {
    static if(!is(CommonType!(ISuiteLifecycleListener, T) == void)) {
      suiteListeners ~= cast(ISuiteLifecycleListener) listener;
      suiteListeners = suiteListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(ITestCaseLifecycleListener, T) == void)) {
      testListeners ~= cast(ITestCaseLifecycleListener) listener;
      testListeners = testListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(IStepLifecycleListener, T) == void)) {
      stepListeners ~= cast(IStepLifecycleListener) listener;
      stepListeners = stepListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(ILifecycleListener, T) == void)) {
      lifecycleListeners ~= cast(ILifecycleListener) listener;
      lifecycleListeners = lifecycleListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(ITestExecutor, T) == void)) {
      executor = cast(ITestExecutor) listener;
    }

    static if(!is(CommonType!(ITestDiscovery, T) == void)) {
      testDiscoveryListeners ~= cast(ITestDiscovery) listener;
      testDiscoveryListeners = testDiscoveryListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(IAttachmentListener, T) == void)) {
      attachmentListeners ~= cast(IAttachmentListener) listener;
      attachmentListeners = attachmentListeners.filter!(a => a !is null).array;
    }
  }

  /// Send the attachment to all listeners
  void attach(ref const Attachment attachment) {
    attachmentListeners.each!(a => a.attach(attachment));
  }

  /// Send the update event to all listeners
  void update() {
    lifecycleListeners.each!"a.update";
  }

  /// Send the begin run event to all listeners
  void begin(ulong testCount) {
    lifecycleListeners.each!(a => a.begin(testCount));
  }

  /// Send the end runer event to all listeners
  void end(SuiteResult[] result) {
    lifecycleListeners.each!(a => a.end(result));
  }

  /// Send the begin suite event to all listeners
  void begin(ref SuiteResult suite) {
    suiteListeners.each!(a => a.begin(suite));
  }

  /// Send the end suite event to all listeners
  void end(ref SuiteResult suite) {
    suiteListeners.each!(a => a.end(suite));
  }

  /// Send the begin test event to all listeners
  void begin(string suite, ref TestResult test) {
    testListeners.each!(a => a.begin(suite, test));
  }

  /// Send the end test event to all listeners
  void end(string suite, ref TestResult test) {
    testListeners.each!(a => a.end(suite, test));
  }

  /// Send the begin step event to all listeners
  void begin(string suite, string test, ref StepResult step) {
    stepListeners.each!(a => a.begin(suite, test, step));
  }

  /// Send the end step event to all listeners
  void end(string suite, string test, ref StepResult step) {
    stepListeners.each!(a => a.end(suite, test, step));
  }

  /// Send the execute test to the executor listener
  SuiteResult[] execute(ref const(TestCase) func) {
    return executor.execute(func);
  }

  /// Send the begin execution with the test case list to the executor listener
  SuiteResult[] beginExecution(ref const(TestCase)[] tests) {
    return executor.beginExecution(tests);
  }

  /// Send the end execution the executor listener
  SuiteResult[] endExecution() {
    return executor.endExecution();
  }
}