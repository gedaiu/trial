/++
  A module containing the ResultReporter

  This is an example of how this reporter looks
  <script type="text/javascript" src="https://asciinema.org/a/12x1mkxfmsj1j0f7qqwarkiyw.js" id="asciicast-12x1mkxfmsj1j0f7qqwarkiyw" async></script>

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.result;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;

import trial.interfaces;
import trial.reporters.writer;

version (Have_fluent_asserts)
{
  import fluentasserts.core.base;
  import fluentasserts.core.results;
}

/// A structure containing the glyphs used for the result reporter
struct TestResultGlyphs {
  version(Windows) {
    ///
    string error = "x";
  } else {
    ///
    string error = "✖";
  }
}

///
string testResultGlyphsToCode(TestResultGlyphs glyphs) {
  return "TestResultGlyphs(`" ~ glyphs.error ~ "`)";
}



/// The "Result" reporter will print an overview of your test run
class ResultReporter : ILifecycleListener, ITestCaseLifecycleListener,
  ISuiteLifecycleListener, IStepLifecycleListener
{
  private
  {
    TestResultGlyphs glyphs;

    int suites;
    int tests;
    int pending;
    int failedTests;

    SysTime beginTime;
    ReportWriter writer;

    Throwable[] exceptions;
    string[] failedTestNames;

    string currentSuite;
  }

  this()
  {
    writer = defaultWriter;
  }

  this(TestResultGlyphs glyphs)
  {
    writer = defaultWriter;
    this.glyphs = glyphs;
  }

  this(ReportWriter writer)
  {
    this.writer = writer;
  }

  void begin(ref SuiteResult suite)
  {
    suites++;
    currentSuite = suite.name;
  }

  void end(ref SuiteResult suite)
  {
  }

  void update()
  {
  }

  void begin(string suite, ref TestResult test)
  {
  }

  void end(string suite, ref TestResult test)
  {
    if(test.status == TestResult.Status.pending) {
      pending++;
    } else {
      tests++;
    }

    if (test.status != TestResult.Status.failure)
    {
      return;
    }

    exceptions ~= test.throwable;
    failedTestNames ~= currentSuite ~ " " ~ test.name;

    failedTests++;
  }

  void begin(string suite, string test, ref StepResult step)
  {
  }

  void end(string suite, string test, ref StepResult step)
  {
  }

  void begin(ulong)
  {
    beginTime = Clock.currTime;
  }

  void end(SuiteResult[] results)
  {
    auto diff = Clock.currTime - beginTime;

    writer.writeln("");

    reportExceptions;

    writer.writeln("");

    if (tests == 0)
    {
      reportNoTest;
    }

    if (tests == 1)
    {
      reportOneTestResult;
    }

    if (tests > 1)
    {
      reportTestsResult;
    }

    if(pending == 1) {
      reportOnePendingTest;
    } else if(pending > 1) {
      reportManyPendingTests;
    }

    writer.writeln("");
  }

  private
  {
    void reportNoTest()
    {
      writer.write("There are no tests to run.");
    }

    void reportOnePendingTest()
    {
      writer.write("There is a pending test.\n", ReportWriter.Context.info);
    }

    void reportManyPendingTests()
    {
      writer.write("There are " ~ pending.to!string ~ " pending tests.\n", ReportWriter.Context.info);
    }

    void reportOneTestResult()
    {
      auto timeDiff = Clock.currTime - beginTime;

      if (failedTests > 0)
      {
        writer.write(glyphs.error ~ " The test failed in " ~ timeDiff.to!string ~ ":",
            ReportWriter.Context.danger);
        return;
      }

      writer.write("The test succeeded in ", ReportWriter.Context.active);
      writer.write(timeDiff.to!string, ReportWriter.Context.info);
      writer.write("!\n", ReportWriter.Context.active);
    }

    void reportTestsResult()
    {
      string suiteText = suites == 1 ? "1 suite" : suites.to!string ~ " suites";
      auto timeDiff = Clock.currTime - beginTime;
      writer.write("Executed ", ReportWriter.Context.active);
      writer.write(tests.to!string, ReportWriter.Context.info);

      if(failedTests > 0) {
        writer.write(" (", ReportWriter.Context.active);
        writer.write(failedTests.to!string ~ " failed", ReportWriter.Context.danger);
        writer.write(")", ReportWriter.Context.active);
      }

      writer.write(" tests in ", ReportWriter.Context.active);
      writer.write(suiteText, ReportWriter.Context.info);
      writer.write(" in ", ReportWriter.Context.active);
      writer.write(timeDiff.to!string, ReportWriter.Context.info);
      writer.write(".\n", ReportWriter.Context.info);
    }

    void reportExceptions()
    {
      foreach (size_t i, t; exceptions)
      {
        writer.writeln("");
        writer.writeln(i.to!string ~ ") " ~ failedTestNames[i] ~ ":", ReportWriter.Context.danger);

        version (Have_fluent_asserts)
        {
          TestException e = cast(TestException) t;

          if (e is null)
          {
            writer.writeln(t.to!string);
          }
          else
          {
            e.print(new TrialResultPrinter(defaultWriter));
          }
        }
        else
        {
          writer.writeln(t.to!string);
        }

        writer.writeln("");
      }
    }
  }
}

version (Have_fluent_asserts) {
  class TrialResultPrinter : ResultPrinter {
    @trusted:
    ReportWriter writer;

    this(ReportWriter writer) {
      this.writer = writer;
    }

    void primary(string text) {
      writer.write(text, ReportWriter.Context._default);
      writer.write("");
    }

    void info(string text) {
      writer.write(text, ReportWriter.Context.info);
      writer.write("");
    }

    void danger(string text) {
      writer.write(text, ReportWriter.Context.danger);
      writer.write("");
    }

    void success(string text) {
      writer.write(text, ReportWriter.Context.success);
      writer.write("");
    }

    void dangerReverse(string text) {
      writer.writeReverse(text, ReportWriter.Context.danger);
      writer.write("");
    }

    void successReverse(string text) {
      writer.writeReverse(text, ReportWriter.Context.success);
      writer.write("");
    }
  }
}

version (unittest)
{
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
}

@("The user should be notified with a message when no test is present")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results;

  reporter.begin(0);
  reporter.end(results);

  writer.buffer.should.contain("There are no tests to run.");
}

@("The user should see a nice message when one test is run")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results = [SuiteResult("some suite")];

  results[0].tests = [new TestResult("some test")];
  results[0].tests[0].status = TestResult.Status.success;

  reporter.begin(1);
  reporter.begin(results[0]);

  reporter.begin("some suite", results[0].tests[0]);
  reporter.end("some suite", results[0].tests[0]);

  reporter.end(results[0]);
  reporter.end(results);

  writer.buffer.should.contain("The test succeeded in");
}

@("The user should see the number of suites and tests when multiple tests are run")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results = [SuiteResult("some suite")];

  results[0].tests = [new TestResult("some test"), new TestResult("other test")];
  results[0].tests[0].status = TestResult.Status.success;
  results[0].tests[1].status = TestResult.Status.success;

  reporter.begin(2);
  reporter.begin(results[0]);

  reporter.begin("some suite", results[0].tests[0]);
  reporter.end("some suite", results[0].tests[0]);

  reporter.begin("some suite", results[0].tests[1]);
  reporter.end("some suite", results[0].tests[1]);

  reporter.end(results[0]);
  reporter.end(results);

  writer.buffer.should.contain("Executed 2 tests in 1 suite in ");
}


@("The user should see the number if there is a pending test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results = [SuiteResult("some suite")];

  results[0].tests = [new TestResult("some test"), new TestResult("other test"), new TestResult("pending test")];
  results[0].tests[0].status = TestResult.Status.success;
  results[0].tests[1].status = TestResult.Status.success;
  results[0].tests[2].status = TestResult.Status.pending;

  reporter.begin(2);
  reporter.begin(results[0]);

  reporter.begin("some suite", results[0].tests[0]);
  reporter.end("some suite", results[0].tests[0]);

  reporter.begin("some suite", results[0].tests[1]);
  reporter.end("some suite", results[0].tests[1]);

  reporter.begin("some suite", results[0].tests[2]);
  reporter.end("some suite", results[0].tests[2]);

  reporter.end(results[0]);
  reporter.end(results);

  writer.buffer.should.contain("Executed 2 tests in 1 suite in ");
  writer.buffer.should.contain("There is a pending test.");
}

@("The user should see the number if there are more than one pending tests")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results = [SuiteResult("some suite")];

  results[0].tests = [new TestResult("some test"), new TestResult("other test"), new TestResult("pending test")];
  results[0].tests[0].status = TestResult.Status.success;
  results[0].tests[1].status = TestResult.Status.pending;
  results[0].tests[2].status = TestResult.Status.pending;

  reporter.begin(2);
  reporter.begin(results[0]);

  reporter.begin("some suite", results[0].tests[0]);
  reporter.end("some suite", results[0].tests[0]);

  reporter.begin("some suite", results[0].tests[1]);
  reporter.end("some suite", results[0].tests[1]);

  reporter.begin("some suite", results[0].tests[2]);
  reporter.end("some suite", results[0].tests[2]);

  reporter.end(results[0]);
  reporter.end(results);

  writer.buffer.should.contain("The test succeeded in");
  writer.buffer.should.contain("There are 2 pending tests.");
}

@("The user should see the reason of a failing test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results = [SuiteResult("some suite")];

  results[0].tests = [new TestResult("some test")];
  results[0].tests[0].status = TestResult.Status.failure;
  results[0].tests[0].throwable = new Exception("Random failure");

  reporter.begin(1);
  reporter.begin(results[0]);

  reporter.begin("some suite", results[0].tests[0]);
  reporter.end("some suite", results[0].tests[0]);

  reporter.end(results[0]);
  reporter.end(results);

  writer.buffer.should.contain("✖ The test failed in");
  writer.buffer.should.contain("0) some suite some test:\n");
}
