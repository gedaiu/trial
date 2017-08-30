/++
  A module containing the TAP13 reporter https://testanything.org/

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.tap;

import std.conv;
import std.string;
import std.algorithm;

import trial.interfaces;
import trial.reporters.writer;

class TapReporter : ILifecycleListener, ITestCaseLifecycleListener
{
  private {
    ReportWriter writer;
  }

  this(ReportWriter writer)
  {
    this.writer = writer;
  }

  void begin(ulong testCount) {
    writer.writeln("TAP version 13", ReportWriter.Context._default);
    writer.writeln("1.." ~ testCount.to!string, ReportWriter.Context._default);
  }

  void update() { }

  void end(SuiteResult[]) { }

  void begin(string suite, ref TestResult)
  {
  }

  void end(string suite, ref TestResult test)
  {
    if(test.status == TestResult.Status.success) {
      writer.writeln("ok - " ~ suite ~ "." ~ test.name, ReportWriter.Context._default);
    } else {

    }
  }
}

version(unittest) import fluent.asserts;

/// it should print "The Plan" at the beginning
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new TapReporter(writer);
  reporter.begin(10);

  writer.buffer.should.equal("TAP version 13\n1..10\n");
}

// it should print a sucess test
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new TapReporter(writer);

  auto test = new TestResult("other test");
  test.status = TestResult.Status.success;

  reporter.end("some suite", test);

  writer.buffer.should.equal("ok - some suite.other test\n");
}