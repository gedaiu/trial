/++
  A module containing the DotMatrixReporter

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.dotmatrix;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;

import trial.interfaces;
import trial.reporters.writer;

/// The dot matrix reporter is simply a series of characters which represent test cases. 
/// Failures highlight in red exclamation marks (!).
/// Good if you prefer minimal output.
class DotMatrixReporter : ITestCaseLifecycleListener
{
  private ReportWriter writer;

  this()
  {
    writer = defaultWriter;
  }

  this(ReportWriter writer)
  {
    this.writer = writer;
  }

  void begin(string suite, ref TestResult test)
  {
  }

  void end(string suite, ref TestResult test)
  {
    switch (test.status)
    {
    case TestResult.Status.success:
      writer.write(".", ReportWriter.Context.inactive);
      break;

    case TestResult.Status.failure:
      writer.write("!", ReportWriter.Context.danger);
      break;

    default:
      writer.write("?", ReportWriter.Context.warning);
    }
  }
}

version (unittest)
{
  import fluent.asserts;
}

@("it should print a success test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new DotMatrixReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  reporter.begin("some suite", test);
  writer.buffer.should.equal("");

  reporter.end("some suite", test);
  writer.buffer.should.equal(".");
}

@("it should print a failing test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new DotMatrixReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.failure;

  reporter.begin("some suite", test);
  writer.buffer.should.equal("");

  reporter.end("some suite", test);
  writer.buffer.should.equal("!");
}
