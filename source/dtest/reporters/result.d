module dtest.reporters.result;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;

import dtest.interfaces;
import dtest.reporters.writer;

class ResultReporter : ILifecycleListener, ITestCaseLifecycleListener, ISuiteLifecycleListener, IStepLifecycleListener {

  private {
    immutable wchar error = '✖';

    int suites;
    int tests;
    int failedTests = 0;

    SysTime beginTime;
    ReportWriter writer;

    Throwable[] exceptions;
    string[] failedTestNames;

    string currentSuite;
  }

  this() {
    version(Have_consoled) {
      writer = new ColorConsoleWriter;
    } else {
      writer = new ConsoleWriter;
    }
  }

  this(ReportWriter writer) {
    this.writer = writer;
  }

  void begin(ref SuiteResult suite) {
    suites++;
    currentSuite = suite.name;
  }

  void end(ref SuiteResult suite) {
  }

  void begin(ref TestResult test) {
    tests++;
  }

  void end(ref TestResult test) {
    if(test.status != TestResult.Status.failure) {
      return;
    }

    exceptions ~= test.throwable;
    failedTestNames ~= currentSuite ~ " " ~ test.name;

    failedTests++;
  }

  void begin(ref StepResult step) {
  }

  void end(ref StepResult test) {
  }

  void begin() {
    beginTime = Clock.currTime;
  }

  void end(SuiteResult[] results) {
    auto diff = Clock.currTime - beginTime;

    writer.writeln("");
    writer.writeln("");

    if(tests == 0) {
      reportNoTest;
    }

    if(tests == 1) {
      reportOneTestResult;
    }

    if(tests > 1) {
      reportTestsResult;
    }

    writer.writeln("");

    reportExceptions;
  }

  private {
    void reportNoTest() {
      writer.write("There are no tests to run.");
    }

    void reportOneTestResult() {
      auto timeDiff = Clock.currTime - beginTime;

      if(failedTests > 0) {
        writer.write("✖ The test failed in " ~ timeDiff.to!string ~":", ReportWriter.Context.danger);
        return;
      }

      writer.write("The test succeeded in " ~ timeDiff.to!string ~"!", ReportWriter.Context.info);
    }

    void reportTestsResult() {
      string suiteText = suites == 1 ? "1 suite" : suites.to!string ~ " suites";
      auto timeDiff = Clock.currTime - beginTime;
      writer.write("Executed " ~ tests.to!string ~ " tests in " ~ suiteText ~ " in " ~ timeDiff.to!string ~ ".\n", ReportWriter.Context.info);
    }

    void reportExceptions() {
      version(Have_fluent_asserts_core) {
        import fluentasserts.core.base;
      }

      foreach(size_t i, t; exceptions) {
        writer.writeln("");
        writer.writeln(i.to!string ~ ") " ~failedTestNames[i] ~ ":", ReportWriter.Context.danger);

        version(Have_fluent_asserts_core) {
          TestException e = cast(TestException) t;

          if(e is null) {
            writer.writeln(t.to!string);
          } else {
            e.source.print;
          }
        } else {
          writer.writeln(t.to!string);
        }

        writer.writeln("");
      }
    }
  }
}

version(unittest) {
  import fluent.asserts;
}

@("The user should be notified with a message ehen no test is present")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results;

  reporter.begin;
  reporter.end(results);

  writer.buffer.should.contain("There are no tests to run.");
}

@("The user should see a nice message when one test is run")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results = [ SuiteResult("some suite") ];

  results[0].tests = [ new TestResult("some test") ];
  results[0].tests[0].status = TestResult.Status.success;

  reporter.begin;
  reporter.begin(results[0]);

  reporter.begin(results[0].tests[0]);
  reporter.end(results[0].tests[0]);

  reporter.end(results[0]);
  reporter.end(results);

  writer.buffer.should.contain("The test succeeded in");
}

@("The user should see the number of suites and tests when multiple tests are run")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results = [ SuiteResult("some suite") ];

  results[0].tests = [ new TestResult("some test"), new TestResult("other test") ];
  results[0].tests[0].status = TestResult.Status.success;
  results[0].tests[1].status = TestResult.Status.success;

  reporter.begin;
  reporter.begin(results[0]);

  reporter.begin(results[0].tests[0]);
  reporter.end(results[0].tests[0]);

  reporter.begin(results[0].tests[1]);
  reporter.end(results[0].tests[1]);

  reporter.end(results[0]);
  reporter.end(results);

  writer.buffer.should.contain("Executed 2 tests in 1 suite in ");
}

@("The user should see the reason of a failing test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new ResultReporter(writer);
  SuiteResult[] results = [ SuiteResult("some suite") ];

  results[0].tests = [ new TestResult("some test") ];
  results[0].tests[0].status = TestResult.Status.failure;
  results[0].tests[0].throwable = new Exception("Random failure");

  reporter.begin;
  reporter.begin(results[0]);

  reporter.begin(results[0].tests[0]);
  reporter.end(results[0].tests[0]);

  reporter.end(results[0]);
  reporter.end(results);

  writer.buffer.should.contain("✖ The test dfailed in");
  writer.buffer.should.contain("0) some suite some test:\n");
}
