/++
  A module containing the Visual Trial reporter used to send data to the
  Visual Studio Code plugin

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.visualtrial;

import std.conv;
import std.string;
import std.algorithm;
import std.stdio;

version(Have_fluent_asserts_core) {
  import fluentasserts.core.base;
  import fluentasserts.core.results;
}

import trial.interfaces;
import trial.reporters.writer;

enum Tokens : string {
  beginTest = "BEGIN TEST;",
  suite = "suite",
  test = "test",
  file = "file",
  line = "line",
  labels = "labels"
}

/// This reporter will print the results using thr Test anything protocol version 13
class VisualTrialReporter : ILifecycleListener, ITestCaseLifecycleListener
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
    writer.writeln("", ReportWriter.Context._default);
    writer.writeln("", ReportWriter.Context._default);
  }

  ///
  void update() { }

  ///
  void end(SuiteResult[]) { }

  ///
  void begin(string suite, ref TestResult result)
  {
    std.stdio.stdout.flush;
    std.stdio.stderr.flush;
    writer.writeln("BEGIN TEST;", ReportWriter.Context._default);
    writer.writeln("suite:" ~ suite, ReportWriter.Context._default);
    writer.writeln("test:" ~ result.name, ReportWriter.Context._default);
    writer.writeln("file:" ~ result.fileName, ReportWriter.Context._default);
    writer.writeln("line:" ~ result.line.to!string, ReportWriter.Context._default);
    writer.writeln("labels:[" ~ result.labels.map!(a => a.toString).join(", ") ~ "]", ReportWriter.Context._default);
    std.stdio.stdout.flush;
    std.stdio.stderr.flush;
  }

  ///
  void end(string suite, ref TestResult test)
  {
    std.stdio.stdout.flush;
    std.stdio.stderr.flush;
    writer.writeln("status:" ~ test.status.to!string, ReportWriter.Context._default);

    if(test.status != TestResult.Status.success) {
      if(test.throwable !is null) {
        writer.writeln("errorFile:" ~ test.throwable.file, ReportWriter.Context._default);
        writer.writeln("errorLine:" ~ test.throwable.line.to!string, ReportWriter.Context._default);
        writer.writeln("message:" ~ test.throwable.msg.split("\n")[0], ReportWriter.Context._default);
        writer.write("error:", ReportWriter.Context._default);
        writer.writeln(test.throwable.toString, ReportWriter.Context._default);
      }
    }

    writer.writeln("END TEST;", ReportWriter.Context._default);

    std.stdio.stdout.flush;
    std.stdio.stderr.flush;
  }
}

version(unittest) {
  import fluent.asserts;
}

/// it should print "The Plan" at the beginning
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new VisualTrialReporter(writer);
  reporter.begin(10);

  writer.buffer.should.equal("\n\n");
}

/// it should print the test location
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new VisualTrialReporter(writer);

  auto test = new TestResult("other test");
  test.fileName = "someFile.d";
  test.line = 100;
  test.labels = [ Label("name", "value"), Label("name1", "value1") ];
  test.status = TestResult.Status.success;

  reporter.begin("some suite", test);

  writer.buffer.should.equal("BEGIN TEST;\n" ~
    "suite:some suite\n" ~
    "test:other test\n" ~
    "file:someFile.d\n" ~
    "line:100\n" ~
    `labels:[{ "name": "name", "value": "value" }, { "name": "name1", "value": "value1" }]` ~ "\n");
}

/// it should print a sucess test
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new VisualTrialReporter(writer);

  auto test = new TestResult("other test");
  test.fileName = "someFile.d";
  test.line = 100;
  test.status = TestResult.Status.success;

  reporter.end("some suite", test);

  writer.buffer.should.equal("status:success\nEND TEST;\n");
}

/// it should print a failing test with a basic throwable
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new VisualTrialReporter(writer);

  auto test = new TestResult("other's test");
  test.status = TestResult.Status.failure;
  test.throwable = new Exception("Test's failure", "file.d", 42);

  reporter.end("some suite", test);

  writer.buffer.should.equal("status:failure\n" ~
         "errorFile:file.d\n" ~
         "errorLine:42\n" ~
         "message:Test's failure\n" ~
         "error:object.Exception@file.d(42): Test's failure\n" ~
         "END TEST;\n");
}

/// it should not print the YAML if the throwable is missing
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new VisualTrialReporter(writer);

  auto test = new TestResult("other's test");
  test.status = TestResult.Status.failure;

  reporter.end("some suite", test);

  writer.buffer.should.equal("status:failure\nEND TEST;\n");
}

/// it should print the results of a TestException
unittest {
  IResult[] results = [
    cast(IResult) new MessageResult("message"),
    cast(IResult) new ExtraMissingResult("a", "b") ];

  auto exception = new TestException(results, "unknown", 0);

  auto writer = new BufferedWriter;
  auto reporter = new VisualTrialReporter(writer);

  auto test = new TestResult("other's test");
  test.status = TestResult.Status.failure;
  test.throwable = exception;

  reporter.end("some suite", test);

  writer.buffer.should.equal("status:failure\n" ~
         "errorFile:unknown\n" ~
         "errorLine:0\n" ~
         "message:message\n" ~
         "error:fluentasserts.core.base.TestException@unknown(0): message\n\n" ~
         "    Extra:a\n" ~
         "  Missing:b\n\n" ~
         "END TEST;\n");
}

/// Parse the output from the visual trial reporter
class VisualTrialReporterParser {
  TestResult testResult;
  string suite;

  /// add a line to the parser
  void add(string line) {
    if(line == Tokens.beginTest) {
      testResult = new TestResult("unknown");
      return;
    }

    auto pos = line.indexOf(":");

    if(pos == -1) {
      return;
    }

    string token = line[0 .. pos];
    string value = line[pos+1 .. $];

    switch(token) {
      case Tokens.suite:
        suite = value;
        break;

      case Tokens.test:
        testResult.name = value;
        break;

      case Tokens.file:
        testResult.fileName = value;
        break;

      case Tokens.line:
        testResult.line = value.to!size_t;
        break;

      case Tokens.labels:
        testResult.labels = Label.fromJsonArray(value);
        break;

      default:
    }
  }
}

/// Parse a successful test
unittest {
  auto parser = new VisualTrialReporterParser();
  parser.testResult.should.beNull;

  parser.add("BEGIN TEST;");
  parser.testResult.should.not.beNull;

  parser.add("suite:suite name");
  parser.suite.should.equal("suite name");

  parser.add("test:test name");
  parser.testResult.name.should.equal("test name");

  parser.add("file:some file.d");
  parser.testResult.fileName.should.equal("some file.d");

  parser.add("line:22");
  parser.testResult.line.should.equal(22);

  parser.add(`labels:[ { "name": "name1", "value": "label1" }, { "name": "name2", "value": "label2" }]`);
  parser.testResult.labels.should.equal([Label("name1", "label1"), Label("name2", "label2")]);
}