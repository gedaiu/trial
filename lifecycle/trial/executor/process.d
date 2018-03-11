/++
  A module containing the process runner

  Copyright: © 2018 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.executors.process;

public import trial.interfaces;

import std.datetime;

/// An executor that will run every test in a separate
/// process
class ProcessExecutor : ITestExecutor {

  /// A function that should spawn a process that will run the test
  alias TestProcesRun = void function(string suiteName, string testName);

  private {
    TestProcesRun testProcesRun;
  }

  /// Instantiate the executor with a custom process runner
  this(TestProcesRun testProcesRun) {
    this.testProcesRun = testProcesRun;
  }

  /// Called before all tests were discovered and they are ready to be executed
  SuiteResult[] beginExecution(ref const(TestCase)[]) {
    return [];
  }

  /// Run a particullary test case
  SuiteResult[] execute(ref const(TestCase) testCase) {
    auto suiteResult = SuiteResult(testCase.suiteName, Clock.currTime);
    auto testResult = new TestResult(testCase.name);
    testResult.begin = Clock.currTime;
    testResult.fileName = testCase.location.fileName;
    testResult.line = testCase.location.line;

    suiteResult.tests ~= testResult;

    this.testProcesRun(testCase.suiteName, testCase.name);

    testResult.status = TestResult.Status.success;
    testResult.end = Clock.currTime;
    suiteResult.end = Clock.currTime;

    return [ suiteResult ];
  }

  /// Called when there is no more test to be executed
  SuiteResult[] endExecution() {
    return [];
  }
}