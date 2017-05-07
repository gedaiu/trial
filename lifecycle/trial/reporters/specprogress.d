module trial.reporters.specprogress;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;

import trial.interfaces;
import trial.reporters.writer;
import trial.reporters.stats;
import trial.reporters.spec;

class SpecProgressReporter : SpecReporter {
  private {
    StatStorage storage;
    string[] path;
  }

  this(StatStorage storage) {
    super();
    this.storage = storage;
  }

  this(ReportWriter writer, StatStorage storage) {
    super(writer);
    this.storage = storage;
  }

  void writeAt(Type t)(string cue, string text = "") {
    writer.goTo(cue);
    write!t(text);
  }

  override {
    void begin(ref SuiteResult suite) {
      path ~= suite.name;
      auto cue = path.join('.');
      auto stat = storage.find(cue);

      indents++;
      write!(Type.emptyLine);
      writeAt!(Type.none)(cue, suite.name ~ ` ~` ~ (stat.end - stat.begin).total!"seconds".to!string ~ "s");
      write!(Type.emptyLine);
    }

    void end(ref SuiteResult suite) {
      auto cue = path.join('.');
      writeAt!(Type.none)(cue, suite.name);
      path = path[0..$-1];


      indents--;
    }

    void begin(ref TestResult test) {
      path ~= test.name;
      auto cue = path.join('.');
      indents++;
      tests++;
      currentStep = 0;
      stepIndents = 0;

      auto stat = storage.find(cue);

      write!(Type.testBegin)(test.name);
      write!(Type.emptyLine);
      writeAt!(Type.testEnd)(cue ~ ".end", "~" ~ (stat.end - stat.begin).total!"seconds".to!string ~ "s");
      write!(Type.emptyLine);
    }

    void end(ref TestResult test) {
      auto cue = path.join('.');
      path = path[0..$-1];
      writeAt!(Type.testEnd)(cue ~ ".end");

      if(test.status == TestResult.Status.success) {
        write!(Type.success)("Success");
      }

      if(test.status == TestResult.Status.failure) {
        write!(Type.failure)("Failure");
        failedTests++;
      }

      indents--;
    }

    void begin(ref StepResult step) {
      path ~= step.name;
    }

    void end(ref StepResult test) {
      path = path[0..$-1];
    }
  }
}

version(unittest) {
  import fluent.asserts;
}

@("it should print a success test")
unittest {
  auto storage = new StatStorage;
  auto begin = SysTime.min;
  auto end = begin + 10.seconds;

  storage.values = [ Stat("some suite", begin, end), Stat("some suite.some test", begin, end) ];

  auto writer = new BufferedWriter;
  auto reporter = new SpecProgressReporter(writer, storage);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  reporter.begin(suite);
  reporter.begin(test);

  writer.buffer.writeln;

  writer.buffer.should.contain("\n  some suite ~10s\n");
  writer.buffer.should.contain("\n    ┌ some test\n");
  writer.buffer.should.contain("\n    └ ~10s\n");

  reporter.end(test);
  reporter.end(suite);

  writer.buffer.writeln;

  writer.buffer.should.contain("\n  some suite\n");
  writer.buffer.should.contain("\n    ┌ some test\n");
  writer.buffer.should.contain("\n    └ ✓ Success\n");
}
