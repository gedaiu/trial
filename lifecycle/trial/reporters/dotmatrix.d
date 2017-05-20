module trial.reporters.dotmatrix;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;

import trial.interfaces;
import trial.reporters.writer;

class DotMatrixReporter : ITestCaseLifecycleListener {

  private ReportWriter writer;

  this() {
    writer = defaultWriter;
  }

  this(ReportWriter writer) {
    this.writer = writer;
  }

  void begin(string suite, ref TestResult test) { }

  void end(string suite, ref TestResult test) {
    switch(test.status) {
      case TestResult.Status.success:
        writer.write(".", ReportWriter.Context.inactive);
        break;

      case TestResult.Status.failure:
        writer.write("!", ReportWriter.Context.danger);
        break;

      default:
        writer.write("?", ReportWriter.Context.warning);
    }
  }
}

version(unittest) {
  import fluent.asserts;
}

@("it should print a success test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new DotMatrixReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  reporter.begin("some suite", test);
  writer.buffer.should.equal("");

  reporter.end("some suite", test);
  writer.buffer.should.equal(".");
}

@("it should print a failing test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new DotMatrixReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.failure;

  reporter.begin("some suite", test);
  writer.buffer.should.equal("");

  reporter.end("some suite", test);
  writer.buffer.should.equal("!");
}
