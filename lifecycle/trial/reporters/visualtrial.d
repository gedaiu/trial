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

version(Have_fluent_asserts_core) {
  import fluentasserts.core.base;
  import fluentasserts.core.results;
}

import trial.interfaces;
import trial.reporters.writer;

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
    writer.writeln("");
    writer.writeln("");
  }

  ///
  void update() { }

  ///
  void end(SuiteResult[]) { }

  ///
  void begin(string suite, ref TestResult result)
  {
    writer.writeln("BEGIN TEST;");
    writer.writeln("suite:" ~ suite);
    writer.writeln("test:" ~ result.name);
  }

  ///
  void end(string suite, ref TestResult test)
  {
    writer.writeln("status:" ~ test.status.to!string);

    if(test.status != TestResult.Status.success) {
      if(test.throwable !is null) {
        writer.writeln("file:" ~ test.throwable.file);
        writer.writeln("line:" ~ test.throwable.line.to!string);
        writer.writeln("message:" ~ test.throwable.msg.split("\n")[0]);
        writer.write("error:");
        writer.writeln(test.throwable.toString);
      }
    }

    writer.writeln("END TEST;");
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

/// it should print a sucess test
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new VisualTrialReporter(writer);

  auto test = new TestResult("other test");
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
         "file:file.d\n" ~
         "line:42\n" ~
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
         "file:unknown\n" ~
         "line:0\n" ~
         "message:message\n" ~
         "error:fluentasserts.core.base.TestException@unknown(0): message\n\n" ~
         "    Extra:a\n" ~
         "  Missing:b\n\n" ~
         "END TEST;\n");
}