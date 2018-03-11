/++
  A module containing the process runner

  Copyright: © 2018 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.executor.process;

import trial.executor.single;
public import trial.interfaces;

import std.process;
import std.path;
import std.file;

import std.datetime;

void testProcessRuner(string suiteName, string testName) {
  import std.stdio;
  writeln([thisExePath, "-s", suiteName, "-t", testName]);

  auto pipes = pipeProcess([thisExePath, "-s", suiteName, "-t", testName], Redirect.stdout | Redirect.stderr);

  wait(pipes.pid);
}

/// An executor that will run every test in a separate
/// process
class ProcessExecutor : DefaultExecutor {
  alias runTest = DefaultExecutor.runTest;

  /// A function that should spawn a process that will run the test
  alias TestProcessRun = void function(string suiteName, string testName);

  private {
    TestProcessRun testProcessRun;
  }

  /// Instantiate the executor with a custom process runner
  this(TestProcessRun testProcessRun) {
    super();

    this.testProcessRun = testProcessRun;
  }

  /// Instantiate the executor with a custom process runner
  this() {
    super();
    this.testProcessRun = &testProcessRuner;
  }

  /// Run a test case
  override
  void runTest(ref const(TestCase) testCase, ref TestResult testResult) {
    testProcessRun(testCase.suiteName, testCase.name);
    testResult.status = TestResult.Status.success;
  }
}