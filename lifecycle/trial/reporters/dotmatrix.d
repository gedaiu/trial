/++
  A module containing the DotMatrixReporter

  This is an example of how this reporter looks
  <script type="text/javascript" src="https://asciinema.org/a/aorvsrruse34n2xym8y7885m1.js" id="asciicast-aorvsrruse34n2xym8y7885m1" async></script>

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

version (Have_fluent_asserts) {
  version = Have_fluent_asserts_core;
}

///
struct DotMatrixGlyphs {
  string success = ".";
  string failure = "!";
  string unknown = "?";
  string pending = "-";
}

///
string dotMatrixGlyphsToCode(DotMatrixGlyphs glyphs) {
  return "DotMatrixGlyphs(`"~ glyphs.success ~"`,`"~ glyphs.failure ~"`,`"~ glyphs.unknown ~"`)";
}

/// The dot matrix reporter is simply a series of characters which represent test cases.
/// Failures highlight in red exclamation marks (!).
/// Good if you prefer minimal output.
class DotMatrixReporter : ITestCaseLifecycleListener
{
  private {
    ReportWriter writer;
    DotMatrixGlyphs glyphs;
  }

  this(DotMatrixGlyphs glyphs)
  {
    writer = defaultWriter;
    this.glyphs = glyphs;
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
      writer.write(glyphs.success, ReportWriter.Context.inactive);
      break;

    case TestResult.Status.failure:
      writer.write(glyphs.failure, ReportWriter.Context.danger);
      break;

    case TestResult.Status.pending:
      writer.write(glyphs.pending, ReportWriter.Context.info);
      break;

    default:
      writer.write(glyphs.unknown, ReportWriter.Context.warning);
    }
  }
}

version (unittest)
{
  version(Have_fluent_asserts_core) {
    import fluent.asserts;
  }
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

@("it should print a pending test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new DotMatrixReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.pending;

  reporter.begin("some suite", test);
  writer.buffer.should.equal("");

  reporter.end("some suite", test);
  writer.buffer.should.equal("-");
}
