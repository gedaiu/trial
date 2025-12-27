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
import std.datetime;
import std.exception;

version(Have_fluent_asserts) {
  import fluentasserts.core.base;
}

import trial.interfaces;
import trial.reporters.writer;

enum Tokens : string {
  beginTest = "BEGIN TEST;",
  endTest = "END TEST;",
  suite = "suite",
  test = "test",
  file = "file",
  line = "line",
  labels = "labels",
  status = "status",
  errorFile = "errorFile",
  errorLine = "errorLine",
  message = "message"
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

/// Parse the output from the visual trial reporter
class VisualTrialReporterParser {
  TestResult testResult;
  string suite;
  bool readingTest;

  alias ResultEvent = void delegate(TestResult);
  alias OutputEvent = void delegate(string);

  ResultEvent onResult;
  OutputEvent onOutput;

  private {
    bool readingErrorMessage;
  }

  /// add a line to the parser
  void add(string line) {
    if(line == Tokens.beginTest) {
      if(testResult is null) {
        testResult = new TestResult("unknown");
      }
      readingTest = true;
      testResult.begin = Clock.currTime;
      testResult.end = Clock.currTime;
      return;
    }

    if(line == Tokens.endTest) {
      enforce(testResult !is null, "The test result was not created!");
      readingTest = false;
      if(onResult !is null) {
        onResult(testResult);
      }

      readingErrorMessage = false;
      testResult = null;
      return;
    }

    if(!readingTest) {
      return;
    }

    if(readingErrorMessage) {
      testResult.throwable.msg ~= "\n" ~ line;
      return;
    }

    auto pos = line.indexOf(":");

    if(pos == -1) {
      if(onOutput !is null) {
        onOutput(line);
      }

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

      case Tokens.status:
        testResult.status = value.to!(TestResult.Status);
        break;

      case Tokens.errorFile:
        if(testResult.throwable is null) {
          testResult.throwable = new ParsedVisualTrialException();
        }
        testResult.throwable.file = value;

        break;

      case Tokens.errorLine:
        if(testResult.throwable is null) {
          testResult.throwable = new ParsedVisualTrialException();
        }
        testResult.throwable.line = value.to!size_t;
        break;

      case Tokens.message:
        enforce(testResult.throwable !is null, "The throwable must exist!");
        testResult.throwable.msg = value;
        readingErrorMessage = true;
        break;

      default:
        if(onOutput !is null) {
          onOutput(line);
        }
    }
  }
}

/// Parse a successful test
unittest {
  auto parser = new VisualTrialReporterParser();
  parser.testResult.should.beNull;
  auto begin = Clock.currTime;

  parser.add("BEGIN TEST;");
  parser.testResult.should.not.beNull;
  parser.testResult.begin.should.be.greaterOrEqualTo(begin);
  parser.testResult.end.should.be.greaterOrEqualTo(begin);
  parser.testResult.status.should.equal(TestResult.Status.created);

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

  parser.add("status:success");
  parser.testResult.status.should.equal(TestResult.Status.success);

  parser.add("END TEST;");
  parser.testResult.should.beNull;
}


/// Parse a failing test
unittest {
  auto parser = new VisualTrialReporterParser();
  parser.testResult.should.beNull;
  auto begin = Clock.currTime;

  parser.add("BEGIN TEST;");

  parser.add("errorFile:file.d");
  parser.add("errorLine:147");
  parser.add("message:line1");
  parser.add("line2");
  parser.add("line3");

  parser.testResult.throwable.should.not.beNull;
  parser.testResult.throwable.file.should.equal("file.d");
  parser.testResult.throwable.line.should.equal(147);

  parser.add("END TEST;");
  parser.testResult.should.beNull;
}

/// Raise an event when the test is ended
unittest {
  bool called;

  void checkResult(TestResult result) {
    called = true;
    result.should.not.beNull;
  }

  auto parser = new VisualTrialReporterParser();
  parser.onResult = &checkResult;

  parser.add("BEGIN TEST;");
  parser.add("END TEST;");

  called.should.equal(true);
}

/// It should not replace a test result that was already assigned
unittest {
  auto testResult = new TestResult("");

  auto parser = new VisualTrialReporterParser();
  parser.testResult = testResult;
  parser.add("BEGIN TEST;");
  parser.testResult.should.equal(testResult);

  parser.add("END TEST;");
  parser.testResult.should.beNull;
}

/// It should raise an event with unparsed lines
unittest {
  bool raised;
  auto parser = new VisualTrialReporterParser();

  void onOutput(string line) {
    line.should.equal("some output");
    raised = true;
  }

  parser.onOutput = &onOutput;
  parser.add("BEGIN TEST;");
  parser.add("some output");

  raised.should.equal(true);
}

class ParsedVisualTrialException : Exception {
  this() {
    super("");
  }
}
