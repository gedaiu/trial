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
auto runTests(string testName = "") {
  return runTests(LifeCycleListeners.instance.getTestCases, testName);
}
