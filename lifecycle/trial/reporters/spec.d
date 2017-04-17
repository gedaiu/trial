module trial.reporters.spec;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;

import trial.interfaces;
import trial.reporters.writer;

class SpecReporter : ITestCaseLifecycleListener, ISuiteLifecycleListener, IStepLifecycleListener {

  private {
    int indents;
    int stepIndents;

    immutable string ok = "✓";
    immutable string current = "┌";
    immutable string line = "│";
    immutable string result = "└";

    int tests;
    int failedTests = 0;
    int currentStep = 0;

    string currentTestName;

    SysTime beginTime;
    ReportWriter writer;
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

  private {
    string indentation() {
      return "  ".replicate(indents);
    }

    string indentation(int cnt) {
      return "  ".replicate(cnt);
    }
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
    currentStep = 0;
    stepIndents = 0;
    currentTestName = test.name;
  }

  void end(ref TestResult test) {
    writer.write(indentation);

    if(currentStep == 0) {
      if(test.status == TestResult.Status.success) {
        writer.write(ok, ReportWriter.Context.success);
        writer.writeln(" " ~ test.name, ReportWriter.Context.inactive);
      }

      if(test.status == TestResult.Status.failure) {
        writer.writeln(failedTests.to!string ~ ") " ~ test.name, ReportWriter.Context.danger);
        failedTests++;
      }
    } else {
      writer.write(result ~ " ", ReportWriter.Context.info);

      if(test.status == TestResult.Status.success) {
        writer.write(ok, ReportWriter.Context.success);
        writer.writeln(" Success");
      }

      if(test.status == TestResult.Status.failure) {
        writer.writeln(failedTests.to!string ~ ") Failure", ReportWriter.Context.danger);
        failedTests++;
      }
    }

    indents--;
  }

  void begin(ref StepResult step) {
    if(currentStep == 0) {
      writer.write(indentation);
      writer.write(current, ReportWriter.Context.info);
      writer.writeln(" " ~ currentTestName, ReportWriter.Context.inactive);
    }

    stepIndents++;

    writer.write(indentation);
    writer.write(line, ReportWriter.Context.info);
    writer.write(indentation(stepIndents));
    writer.writeln(" " ~ step.name, ReportWriter.Context.inactive);
    currentStep++;
  }

  void end(ref StepResult test) {
    stepIndents--;
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

@("it should format the steps for a success test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  auto step = new StepResult();
  step.name = "some step";

  reporter.begin(suite);
  reporter.begin(test);

  reporter.begin(step);
  reporter.begin(step);
  reporter.end(step);
  reporter.end(step);
  reporter.begin(step);
  reporter.end(step);

  reporter.end(test);

  reporter.begin(test);
  reporter.end(test);

  reporter.end(suite);

  writer.buffer.should.equal("\n" ~
                             "  some suite\n" ~
                             "    ┌ some test\n" ~
                             "    │   some step\n" ~
                             "    │     some step\n" ~
                             "    │   some step\n" ~
                             "    └ ✓ Success\n" ~
                             "    ✓ some test\n");
}


@("it should format the steps for a failing test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.failure;

  auto step = new StepResult();
  step.name = "some step";

  reporter.begin(suite);
  reporter.begin(test);

  reporter.begin(step);
  reporter.begin(step);
  reporter.end(step);
  reporter.end(step);
  reporter.begin(step);
  reporter.end(step);

  reporter.end(test);

  reporter.begin(test);
  reporter.end(test);

  reporter.end(suite);

  writer.buffer.should.equal("\n" ~
                             "  some suite\n" ~
                             "    ┌ some test\n" ~
                             "    │   some step\n" ~
                             "    │     some step\n" ~
                             "    │   some step\n" ~
                             "    └ 0) Failure\n" ~
                             "    1) some test\n");
}
