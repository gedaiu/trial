/++
  A module containing the LandingReporter

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.landing;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;

import trial.interfaces;
import trial.reporters.writer;

/// The Landing Strip (landing) reporter is a gimmicky test reporter simulating a plane landing unicode ftw
class LandingReporter : ITestCaseLifecycleListener, ILifecycleListener
{
  private
  {
    ReportWriter writer;
    const
    {
      string plane = "✈";
      string margin = "━";
      string lane = "⋅";
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
    writer.writeln("\n\n");
    drawLane;
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
    drawLane;
  }

  private void drawLane()
  {
    int size = (writer.width / 4) * 3;
    ulong position = ((cast(double) currentTest / cast(double) testCount) * size).to!long;

    writer.goTo(3);
    writer.writeln(margin.replicate(size), ReportWriter.Context.inactive);

    if (currentTest < testCount)
    {
      writer.write(lane.replicate(position), ReportWriter.Context.inactive);
      writer.write(plane, success ? ReportWriter.Context.active : ReportWriter.Context.danger);
      writer.writeln(lane.replicate(size - position - 1), ReportWriter.Context.inactive);
    }
    else
    {
      writer.write(lane.replicate(size), ReportWriter.Context.inactive);
      writer.writeln(plane, success ? ReportWriter.Context.active : ReportWriter.Context.danger);
    }

    writer.writeln(margin.replicate(size), ReportWriter.Context.inactive);
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
  auto reporter = new LandingReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;
  reporter.begin(10);

  writer.buffer.should.equal("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" ~ "✈⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅\n" ~ "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  auto position = [18, 36, 54, 72, 90, 108, 126, 144, 162, 180];

  foreach (i; 0 .. 10)
  {
    reporter.begin("some suite", test);
    reporter.end("some suite", test);

    auto lines = writer.buffer.split("\n");
    lines.length.should.equal(4);
    lines[1].indexOf("✈").should.equal(position[i]);
  }
}
