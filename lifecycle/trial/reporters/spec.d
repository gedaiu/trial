module trial.reporters.spec;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;

import trial.interfaces;
import trial.reporters.writer;

class SpecReporter : ITestCaseLifecycleListener {
  enum Type {
    none,
    success,
    step,
    failure,
    testBegin,
    testEnd,
    emptyLine
  }

  protected {
    int failedTests = 0;
    string lastSuiteName;

    ReportWriter writer;
  }

  private {
    immutable string ok = "✓";
    immutable string current = "┌";
    immutable string line = "│";
    immutable string result = "└";
  }

  this() {
    writer = defaultWriter;
  }

  this(ReportWriter writer) {
    this.writer = writer;
  }

  private {
    string indentation(ulong cnt) pure {
      return "  ".replicate(cnt);
    }
  }

  void write(Type t)(string text = "", ulong spaces = 0) {
    writer.write(indentation(spaces));

    switch(t) {
      case Type.emptyLine:
        writer.writeln("");
        break;

      case Type.success:
        writer.write(ok, ReportWriter.Context.success);
        writer.write(" " ~ text, ReportWriter.Context.inactive);
        break;

      case Type.failure:
        writer.write(failedTests.to!string ~ ") " ~ text, ReportWriter.Context.danger);
        break;

      default:
        writer.write(text);
    }
  }

  void begin(string suite, ref TestResult test) { }

  void end(string suite, ref TestResult test) {
    ulong indents = 1;

    if(suite != lastSuiteName) {
      auto oldPieces = lastSuiteName.split(".");
      auto pieces = suite.split(".");
      lastSuiteName = suite;

      auto prefix = oldPieces.commonPrefix(pieces).array.length;

      write!(Type.emptyLine)();
      indents += prefix;

      foreach(piece; pieces[prefix .. $]) {
        write!(Type.none)(piece, indents);
        write!(Type.emptyLine)();
        indents++;
      }

    } else {
      indents = suite.count('.') + 2;
    }

    if(test.status == TestResult.Status.success) {
      write!(Type.success)(test.name, indents);
    }

    if(test.status == TestResult.Status.failure) {
      write!(Type.failure)(test.name, indents);
      failedTests++;
    }

    write!(Type.emptyLine);

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

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  writer.buffer.should.equal("\n  some suite" ~
                             "\n    ✓ some test\n");
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

  reporter.begin("some suite", test1);
  reporter.end("some suite", test1);

  reporter.begin("some suite", test2);
  reporter.end("some suite", test2);

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

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  writer.buffer.should.equal("\n  some suite" ~
                             "\n    0) some test\n");
}

@("it should split suites by dot")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some.suite");
  auto test = new TestResult("some test");

  test.status = TestResult.Status.failure;
  test.throwable = new Exception("Random failure");

  reporter.end("some.suite", test);
  reporter.end("some.suite", test);

  writer.buffer.should.equal("\n" ~
                             "  some\n" ~
                             "    suite\n" ~
                             "      0) some test\n" ~
                             "      1) some test\n");
}

@("it should omit the common suite names")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some.suite");
  auto test = new TestResult("some test");

  test.status = TestResult.Status.failure;
  test.throwable = new Exception("Random failure");

  reporter.end("some.suite", test);
  reporter.end("some.other", test);

  writer.buffer.should.equal("\n" ~
                             "  some\n" ~
                             "    suite\n" ~
                             "      0) some test\n\n"
                             "    other\n" ~
                             "      1) some test\n");
}
