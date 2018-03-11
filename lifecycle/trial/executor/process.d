/++
  A module containing the process runner

  Copyright: © 2018 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.executor.process;

import trial.reporters.visualtrial;
import trial.executor.single;
public import trial.interfaces;

import std.process;
import std.path;
import std.file;
import std.datetime;
import std.conv;

void testProcessRuner(string suiteName, string testName, VisualTrialReporterParser parser) {
  import std.stdio;

  auto command = [ thisExePath, 
    "-s", suiteName,
    "-t", testName,
    "-r", "visualtrial",
    "-e", "default" ];

  auto pipes = pipeProcess(command, Redirect.stdout | Redirect.stderrToStdout);

  foreach(line; pipes.stdout.byLine) {
    parser.add(line.to!string);
  }

  wait(pipes.pid);
}

/// An executor that will run every test in a separate
/// process
class ProcessExecutor : DefaultExecutor {
  alias runTest = DefaultExecutor.runTest;

  /// A function that should spawn a process that will run the test
  alias TestProcessRun = void function(string suiteName, string testName, VisualTrialReporterParser parser);

  private {
    TestProcessRun testProcessRun;
    VisualTrialReporterParser parser;
  }

  /// Instantiate the executor with a custom process runner
  this(TestProcessRun testProcessRun) {
    super();

    this.parser = new VisualTrialReporterParser();
    this.testProcessRun = testProcessRun;
  }

  /// Instantiate the executor with a custom process runner
  this() {
    this(&testProcessRuner);
  }

  /// Run a test case
  override
  void runTest(ref const(TestCase) testCase, TestResult testResult) {
    this.parser.testResult = testResult;
    testProcessRun(testCase.suiteName, testCase.name, parser);
  }
}