/++
  A module containing the SpecReporter

  This is an example of how this reporter looks
  <script type="text/javascript" src="https://asciinema.org/a/9z1tolgn7x55v41i3mm3wlkum.js" id="asciicast-9z1tolgn7x55v41i3mm3wlkum" async></script>

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.spec;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;

import trial.interfaces;
import trial.settings;
import trial.reporters.writer;

/// A structure containing the glyphs used for the spec reporter
struct SpecGlyphs {
  version(Windows) {
    ///
    string ok = "+";
  } else {
    ///
    string ok = "✓";
  }

  string pending = "-";
}

///
string specGlyphsToCode(SpecGlyphs glyphs) {
  return "SpecGlyphs(`" ~ glyphs.ok ~ "`)";
}

/// This is the default reporter. The "spec" reporter outputs a hierarchical view nested just as the test cases are.
class SpecReporter : ITestCaseLifecycleListener
{
  enum Type
  {
    none,
    success,
    step,
    pending,
    failure,
    testBegin,
    testEnd,
    emptyLine,
    danger,
    warning
  }

  protected
  {
    int failedTests = 0;
    string lastSuiteName;

    ReportWriter writer;
  }

  private
  {
    Settings settings;
  }

  this()
  {
    writer = defaultWriter;
  }

  this(Settings settings)
  {
    writer = defaultWriter;
    this.settings = settings;
  }

  this(ReportWriter writer)
  {
    this.writer = writer;
  }

  private
  {
    string indentation(size_t cnt) pure
    {
      return "  ".replicate(cnt);
    }
  }

  void write(Type t)(string text = "", size_t spaces = 0)
  {
    writer.write(indentation(spaces));

    switch (t)
    {
    case Type.emptyLine:
      writer.writeln("");
      break;

    case Type.success:
      writer.write(settings.glyphs.spec.ok, ReportWriter.Context.success);
      writer.write(" " ~ text, ReportWriter.Context.inactive);
      break;

    case Type.pending:
      writer.write(settings.glyphs.spec.pending, ReportWriter.Context.info);
      writer.write(" " ~ text, ReportWriter.Context.inactive);
      break;

    case Type.failure:
      writer.write(failedTests.to!string ~ ") " ~ text,
          ReportWriter.Context.danger);
      break;

    case Type.danger:
      writer.write(text, ReportWriter.Context.danger);
      break;

    case Type.warning:
      writer.write(text, ReportWriter.Context.warning);
      break;

    default:
      writer.write(text);
    }
  }

  void begin(string suite, ref TestResult test)
  {
  }

  protected auto printSuite(string suite) {
    size_t indents = 1;

    auto oldPieces = lastSuiteName.split(".");
    auto pieces = suite.split(".");
    lastSuiteName = suite;

    auto prefix = oldPieces.commonPrefix(pieces).array.length;

    write!(Type.emptyLine)();
    indents += prefix;

    foreach (piece; pieces[prefix .. $])
    {
      write!(Type.none)(piece, indents);
      write!(Type.emptyLine)();
      indents++;
    }

    return indents;
  }

  void end(string suite, ref TestResult test)
  {
    size_t indents = 1;

    if (suite != lastSuiteName)
    {
      indents = printSuite(suite);
    }
    else
    {
      indents = suite.count('.') + 2;
    }

    if (test.status == TestResult.Status.success)
    {
      write!(Type.success)(test.name, indents);
    }

    if (test.status == TestResult.Status.pending)
    {
      write!(Type.pending)(test.name, indents);
    }

    if (test.status == TestResult.Status.failure)
    {
      write!(Type.failure)(test.name, indents);
      failedTests++;
    }

    auto timeDiff = (test.end - test.begin).total!"msecs";

    if(timeDiff >= settings.warningTestDuration && timeDiff < settings.dangerTestDuration) {
      write!(Type.warning)(" (" ~ timeDiff.to!string ~ "ms)", 0);
    }

    if(timeDiff >= settings.dangerTestDuration) {
      write!(Type.danger)(" (" ~ timeDiff.to!string ~ "ms)", 0);
    }

    write!(Type.emptyLine);

    indents--;
  }
}

version (unittest)
{
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
}

@("it should print a success test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  writer.buffer.should.equal("\n  some suite" ~ "\n    ✓ some test\n");
}

@("it should print two success tests")
unittest
{
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
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");

  test.status = TestResult.Status.failure;

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  writer.buffer.should.equal("\n  some suite" ~ "\n    0) some test\n");
}

@("it should print a pending test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");

  test.status = TestResult.Status.pending;

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  writer.buffer.should.equal("\n  some suite" ~ "\n    - some test\n");
}

@("it should split suites by dot")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some.suite");
  auto test = new TestResult("some test");

  test.status = TestResult.Status.failure;
  test.throwable = new Exception("Random failure");

  reporter.end("some.suite", test);
  reporter.end("some.suite", test);

  writer.buffer.should.equal(
      "\n" ~ "  some\n" ~ "    suite\n" ~ "      0) some test\n" ~ "      1) some test\n");
}

@("it should omit the common suite names")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some.suite");
  auto test = new TestResult("some test");

  test.status = TestResult.Status.failure;
  test.throwable = new Exception("Random failure");

  reporter.end("some.suite", test);
  reporter.end("some.other", test);

  writer.buffer.should.equal(
      "\n" ~ "  some\n" ~ "    suite\n" ~ "      0) some test\n\n" ~ "    other\n"
      ~ "      1) some test\n");
}

/// it should print the test duration
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some.suite");
  auto test = new TestResult("some test");

  test.status = TestResult.Status.success;
  test.end = Clock.currTime;
  test.begin = test.end - 1.seconds;

  test.throwable = new Exception("Random failure");

  reporter.end("some.suite", test);

  writer.buffer.should.equal(
      "\n" ~ "  some\n" ~ "    suite\n" ~ "      ✓ some test (1000ms)\n");
}
