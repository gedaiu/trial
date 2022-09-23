/++
  A module containing the SpecStepsReporter

  This is an example of how this reporter looks
  <script type="text/javascript" src="https://asciinema.org/a/bsk6do8t4zay9k9vznvh8yn71.js" id="asciicast-bsk6do8t4zay9k9vznvh8yn71" async></script>

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.specsteps;

import trial.interfaces;
import trial.reporters.spec;
import trial.reporters.writer;
import trial.settings;

import std.datetime;
import std.conv;

/// A structure containing the glyphs used for the spec steps reporter
struct SpecStepsGlyphs {
  version(Windows) {
    ///
    string testBegin = "/";

    ///
    string testEnd = "\\";

    ///
    string step = "|";
  } else {
    ///
    string testBegin = "┌";

    ///
    string testEnd = "└";

    ///
    string step = "│";
  }
}

///
string specStepsGlyphsToCode(SpecStepsGlyphs glyphs) {
  return "SpecStepsGlyphs(`" ~ glyphs.testBegin ~ "`, `" ~ glyphs.testEnd ~ "`, `" ~ glyphs.step ~ "`)";
}

/// A flavour of the "spec" reporter that show the tests and the steps of your tests.
class SpecStepsReporter : SpecReporter, ISuiteLifecycleListener, IStepLifecycleListener
{
  private {
    size_t indents;
    size_t stepIndents;

    Settings settings;
  }


  this(Settings settings)
  {
    super(settings);
    this.settings = settings;
  }

  this(ReportWriter writer)
  {
    super(writer);
  }

  void begin(ref SuiteResult suite)
  {
    indents = printSuite(suite.name);
  }

  void end(ref SuiteResult) { }

  override
  {
    void begin(string suite, ref TestResult test)
    {
      stepIndents = 0;
      write!(Type.none)(settings.glyphs.specSteps.testBegin ~ " " ~ test.name ~ "\n", indents);
    }

    void end(string suite, ref TestResult test)
    {
      write!(Type.none)(settings.glyphs.specSteps.testEnd ~ " ", indents);

      if(test.status == TestResult.Status.success) {
        write!(Type.success)("Success", 0);
      } else if(test.status == TestResult.Status.failure) {
        write!(Type.failure)("Failure", 0);
        failedTests++;
      } else if(test.status == TestResult.Status.pending) {
        write!(Type.pending)("Pending", 0);
      } else {
        write!(Type.none)("Unknown", 0);
      }

      auto timeDiff = (test.end - test.begin).total!"msecs";

      if(timeDiff >= settings.warningTestDuration && timeDiff < settings.dangerTestDuration) {
        write!(Type.warning)(" (" ~ timeDiff.to!string ~ "ms)", 0);
      }

      if(timeDiff >= settings.dangerTestDuration) {
        write!(Type.danger)(" (" ~ timeDiff.to!string ~ "ms)", 0);
      }

      write!(Type.none)("\n", 0);
    }
  }

  void begin(string suite, string test, ref StepResult s)
  {
    stepIndents++;
    write!(Type.none)(settings.glyphs.specSteps.step, indents);
    write!(Type.none)(" " ~ s.name ~ "\n", stepIndents);
  }

  void end(string suite, string test, ref StepResult)
  {
    stepIndents--;
  }
}

version (unittest)
{
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
}

@("it should format the steps for a success test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecStepsReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  auto step = new StepResult();
  step.name = "some step";

  reporter.begin(suite);
  reporter.begin("some suite", test);

  reporter.begin("some suite", "some test", step);
  reporter.begin("some suite", "some test", step);
  reporter.end("some suite", "some test", step);
  reporter.end("some suite", "some test", step);
  reporter.begin("some suite", "some test", step);
  reporter.end("some suite", "some test", step);

  reporter.end("some suite", test);

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  reporter.end(suite);

  writer.buffer.should.equal("\n" ~
        "  some suite\n" ~
        "    ┌ some test\n" ~
        "    │   some step\n" ~
        "    │     some step\n" ~
        "    │   some step\n" ~
        "    └ ✓ Success\n" ~
        "    ┌ some test\n" ~
        "    └ ✓ Success\n");
}

@("it should format a pending test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecStepsReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.pending;

  reporter.begin(suite);
  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  reporter.end(suite);

  writer.buffer.should.equal("\n" ~
        "  some suite\n" ~
        "    ┌ some test\n" ~
        "    └ - Pending\n");
}


@("it should print the duration of a long test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecStepsReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;
  test.end = Clock.currTime;
  test.begin = test.end - 200.msecs;

  reporter.begin(suite);
  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  reporter.end(suite);

  writer.buffer.should.equal("\n" ~
        "  some suite\n" ~
        "    ┌ some test\n" ~
        "    └ ✓ Success (200ms)\n");
}


@("it should format the steps for a failing test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new SpecStepsReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.failure;

  auto step = new StepResult();
  step.name = "some step";

  reporter.begin(suite);
  reporter.begin("some suite", test);

  reporter.begin("some suite", "some test", step);
  reporter.begin("some suite", "some test", step);
  reporter.end("some suite", "some test", step);
  reporter.end("some suite", "some test", step);
  reporter.begin("some suite", "some test", step);
  reporter.end("some suite", "some test", step);

  reporter.end("some suite", test);

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  reporter.end(suite);

  writer.buffer.should.equal("\n" ~
      "  some suite\n" ~
      "    ┌ some test\n" ~
      "    │   some step\n" ~
      "    │     some step\n" ~
      "    │   some step\n" ~
      "    └ 0) Failure\n" ~
      "    ┌ some test\n" ~
      "    └ 1) Failure\n");
}
