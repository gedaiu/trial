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

/// A structure containing the glyphs used for the spec steps reporter
struct SpecStepsGlyphs {
  ///
  string testBegin = "┌";

  ///
  string testEnd = "└";

  ///
  string step = "│";
}

///
string toCode(SpecStepsGlyphs glyphs) {
  return "SpecStepsGlyphs(`" ~ glyphs.testBegin ~ "`, `" ~ glyphs.testEnd ~ "`, `" ~ glyphs.step ~ "`)";
}

/// A flavour of the "spec" reporter that show the tests and the steps of your tests.
class SpecStepsReporter : SpecReporter, ISuiteLifecycleListener, IStepLifecycleListener
{
  private {
    size_t indents;
    size_t stepIndents;

    SpecStepsGlyphs glyphs;
  }


  this(SpecStepsGlyphs glyphs)
  {
    super();
    this.glyphs = glyphs;
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
      write!(Type.none)(glyphs.testBegin ~ " " ~ test.name ~ "\n", indents);
    }

    void end(string suite, ref TestResult test)
    {
      write!(Type.none)(glyphs.testEnd ~ " ", indents);

      if(test.status == TestResult.Status.success) {
        write!(Type.success)("Success\n", 0);
      } else if(test.status == TestResult.Status.failure) {
        write!(Type.failure)("Failure\n", 0);
        failedTests++;
      } else {
        write!(Type.none)("Unknown\n", 0);
      }
    }
  }

  void begin(string suite, string test, ref StepResult s)
  {
    stepIndents++;
    write!(Type.none)(glyphs.step, indents);
    write!(Type.none)(" " ~ s.name ~ "\n", stepIndents);

  }

  void end(string suite, string test, ref StepResult)
  {
    stepIndents--;
  }
}

version (unittest)
{
  import fluent.asserts;
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
