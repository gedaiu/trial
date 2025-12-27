/++
  A module containing the TAP13 reporter https://testanything.org/

  This is an example of how this reporter looks
  <script type="text/javascript" src="https://asciinema.org/a/135734.js" id="asciicast-135734" async></script>

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.tap;

import std.conv;
import std.string;
import std.algorithm;

version(Have_fluent_asserts) {
  import fluentasserts.core.base;
}

import trial.interfaces;
import trial.reporters.writer;

/// This reporter will print the results using thr Test anything protocol version 13
class TapReporter : ILifecycleListener, ITestCaseLifecycleListener
{
  private {
    ReportWriter writer;
  }

  ///
  this()
  {
    writer = defaultWriter;
  }

  ///
  this(ReportWriter writer)
  {
    this.writer = writer;
  }

  ///
  void begin(ulong testCount) {
    writer.writeln("TAP version 13", ReportWriter.Context._default);
    writer.writeln("1.." ~ testCount.to!string, ReportWriter.Context._default);
  }

  ///
  void update() { }

  ///
  void end(SuiteResult[]) { }

  ///
  void begin(string, ref TestResult)
  {
  }

  ///
  void end(string suite, ref TestResult test)
  {
    if(test.status == TestResult.Status.success) {
      writer.writeln("ok - " ~ suite ~ "." ~ test.name, ReportWriter.Context._default);
    } else {
      writer.writeln("not ok - " ~ suite ~ "." ~ test.name, ReportWriter.Context._default);

      version(Have_fluent_asserts) {
        if(test.throwable !is null) {
          if(cast(TestException) test.throwable !is null) {
            printTestException(test);
          } else {
            printThrowable(test);
          }

          writer.writeln("");
        }
      } else {
        printThrowable(test);
      }
    }
  }

  version(Have_fluent_asserts) {
    private void printTestException(ref TestResult test) {
      auto diagnostic = test.throwable.msg.split("\n").map!(a => "# " ~ a).join("\n");

      auto msg = test.throwable.msg.split("\n")[0];

      writer.writeln(diagnostic, ReportWriter.Context._default);
      writer.writeln("  ---", ReportWriter.Context._default);
      writer.writeln("  message: '" ~ msg ~ "'", ReportWriter.Context._default);
      writer.writeln("  severity: " ~ test.status.to!string, ReportWriter.Context._default);
      writer.writeln("  location:", ReportWriter.Context._default);
      writer.writeln("    fileName: '" ~ test.throwable.file.replace("'", "\'") ~ "'", ReportWriter.Context._default);
      writer.writeln("    line: " ~ test.throwable.line.to!string, ReportWriter.Context._default);
    }
  }

  private void printThrowable(ref TestResult test) {
    writer.writeln("  ---", ReportWriter.Context._default);
    writer.writeln("  message: '" ~ test.throwable.msg ~ "'", ReportWriter.Context._default);
    writer.writeln("  severity: " ~ test.status.to!string, ReportWriter.Context._default);
    writer.writeln("  location:", ReportWriter.Context._default);
    writer.writeln("    fileName: '" ~ test.throwable.file.replace("'", "\'") ~ "'", ReportWriter.Context._default);
    writer.writeln("    line: " ~ test.throwable.line.to!string, ReportWriter.Context._default);
  }
}

version(unittest) {
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
}

/// it should print "The Plan" at the beginning
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new TapReporter(writer);
  reporter.begin(10);

  writer.buffer.should.equal("TAP version 13\n1..10\n");
}

/// it should print a sucess test
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new TapReporter(writer);

  auto test = new TestResult("other test");
  test.status = TestResult.Status.success;

  reporter.end("some suite", test);

  writer.buffer.should.equal("ok - some suite.other test\n");
}

/// it should print a failing test with a basic throwable
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new TapReporter(writer);

  auto test = new TestResult("other's test");
  test.status = TestResult.Status.failure;
  test.throwable = new Exception("Test's failure", "file.d", 42);

  reporter.end("some suite", test);

  writer.buffer.should.equal("not ok - some suite.other's test\n" ~
  "  ---\n" ~
  "  message: 'Test\'s failure'\n" ~
  "  severity: failure\n" ~
  "  location:\n" ~
  "    fileName: 'file.d'\n" ~
  "    line: 42\n\n");
}

/// it should not print the YAML if the throwable is missing
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new TapReporter(writer);

  auto test = new TestResult("other's test");
  test.status = TestResult.Status.failure;

  reporter.end("some suite", test);

  writer.buffer.should.equal("not ok - some suite.other's test\n");
}

