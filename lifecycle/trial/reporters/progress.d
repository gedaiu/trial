/++
  A module containing the ProgressReporter
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

/// The “progress” reporter implements a simple progress-bar
class ProgressReporter : ITestCaseLifecycleListener, ILifecycleListener
{
  private
  {
    ReportWriter writer;
    const
    {
      string empty = "░";
      string fill = "▓";
    }

    ulong testCount;
    ulong currentTest;
    bool success = true;
  }
  this()
  {
    writer = defaultWriter;
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
    ulong position = ((cast(double) currentTest / cast(double) testCount) * size).to!long;

    writer.goTo(1);

    writer.write(currentTest.to!string ~ "/" ~ testCount.to!string ~ " ",
        success ? ReportWriter.Context.active : ReportWriter.Context.danger);

    writer.write(fill.replicate(position), ReportWriter.Context.active);
    writer.writeln(empty.replicate(size - position), ReportWriter.Context.inactive);
  }
}

version (unittest)
{
  import fluent.asserts;
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
