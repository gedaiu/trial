module dtest.reporters.spec;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;

import dtest.interfaces;
import dtest.reporters.writer;

class SpecReporter : ITestCaseLifecycleListener, ISuiteLifecycleListener, IStepLifecycleListener {

  private {
    int indents;

    immutable wchar ok = '✓';
    immutable wchar error = '✖';

    int tests;
    int failedTests = 0;

    SysTime beginTime;
    ReportWriter writer;
  }

  this() {
    writer = new ConsoleWriter;
  }

  this(ReportWriter writer) {
    this.writer = writer;
  }

  private string indentation() {
    return "  ".replicate(indents);
  }

  void begin(ref SuiteResult suite) {
    indents++;
    writer.writeln("\n" ~ indentation ~ suite.name);
  }

  void end(ref SuiteResult suite) {
    indents--;
  }

  void begin(ref TestResult test) {
    indents++;
    tests++;
  }

  void end(ref TestResult test) {
    string message = indentation;

    if(test.status == TestResult.Status.success) {
      message ~= ok;
    }

    if(test.status == TestResult.Status.failure) {
      message ~= failedTests.to!string ~ ")";
      failedTests++;
    }

    message ~= " " ~ test.name;
    writer.writeln(message);
    indents--;
  }

  void begin(ref StepResult step) {
    indents++;
    writeln(indentation, step.name);
  }

  void end(ref StepResult test) {
    indents--;
  }
}

version(unittest) {
  import fluent.asserts;
}

@("it should print a success test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  reporter.begin(suite);

  reporter.begin(test);
  reporter.end(test);

  reporter.end(suite);

  writer.buffer.should.contain("\n  some suite\n");
  writer.buffer.should.contain("\n    ✓ some test\n");
}

@("it should print two success tests")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test1 = new TestResult("some test");
  test1.status = TestResult.Status.success;

  auto test2 = new TestResult("other test");
  test2.status = TestResult.Status.success;

  reporter.begin(suite);

  reporter.begin(test1);
  reporter.end(test1);

  reporter.begin(test2);
  reporter.end(test2);

  reporter.end(suite);

  writer.buffer.should.contain("\n  some suite\n");
  writer.buffer.should.contain("\n    ✓ some test\n");
  writer.buffer.should.contain("\n    ✓ other test\n");
}

@("it should print a failing test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");

  test.status = TestResult.Status.failure;
  test.throwable = new Exception("Random failure");

  reporter.begin(suite);
  reporter.begin(test);
  reporter.end(test);
  reporter.end(suite);

  writer.buffer.should.contain("\n  some suite\n");
  writer.buffer.should.contain("\n    0) some test\n");
}
