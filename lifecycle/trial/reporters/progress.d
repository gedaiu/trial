/++
  A module containing the ProgressReporter

  This is an example of how this reporter looks
  <script type="text/javascript" src="https://asciinema.org/a/a3aspcv8cw5l04l59xw9vbtqa.js" id="asciicast-a3aspcv8cw5l04l59xw9vbtqa" async></script>

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.progress;

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
struct ProgressGlyphs {
  version(Windows) {
    string empty = ".";
    string fill = "#";
  } else {
    string empty = "░";
    string fill = "▓";
  }
}

///
string progressGlyphsToCode(ProgressGlyphs glyphs) {
  return "ProgressGlyphs(`" ~ glyphs.empty ~ "`,`" ~ glyphs.fill ~ "`)";
}

/// The “progress” reporter implements a simple progress-bar
class ProgressReporter : ITestCaseLifecycleListener, ILifecycleListener
{
  private
  {
    ReportWriter writer;
    ProgressGlyphs glyphs;

    ulong testCount;
    ulong currentTest;
    bool success = true;
  }
  this(ProgressGlyphs glyphs)
  {
    writer = defaultWriter;
    this.glyphs = glyphs;
  }

  this(ReportWriter writer)
  {
    this.writer = writer;
  }

  void begin(ulong testCount)
  {
    this.testCount = testCount;
    writer.writeln("");
    draw;
  }

  void update()
  {

  }

  void end(SuiteResult[])
  {

  }

  void begin(string suite, ref TestResult test)
  {
  }

  void end(string suite, ref TestResult test)
  {
    currentTest++;
    success = success && test.status == TestResult.Status.success;
    draw;
  }

  private void draw()
  {
    int size = min((writer.width / 4) * 3, testCount);
    size_t position = ((cast(double) currentTest / cast(double) testCount) * size).to!size_t;

    writer.goTo(1);

    writer.write(currentTest.to!string ~ "/" ~ testCount.to!string ~ " ",
        success ? ReportWriter.Context.active : ReportWriter.Context.danger);

    writer.write(glyphs.fill.replicate(position), ReportWriter.Context.active);
    writer.writeln(glyphs.empty.replicate(size - position), ReportWriter.Context.inactive);
  }
}

version (unittest)
{
  version(Have_fluent_asserts_core) {
    import fluent.asserts;
  }
}

@("it should print 10 success tests")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new ProgressReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;
  reporter.begin(10);

  writer.buffer.should.equal("0/10 ░░░░░░░░░░\n");

  foreach (i; 0 .. 10)
  {
    reporter.begin("some suite", test);
    reporter.end("some suite", test);
  }

  writer.buffer.should.equal("10/10 ▓▓▓▓▓▓▓▓▓▓\n");
}
