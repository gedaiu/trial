module trial.reporters.specprogress;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.algorithm;

import trial.interfaces;
import trial.reporters.writer;
import trial.reporters.stats;
import trial.reporters.spec;

class SpecProgressReporter : SpecReporter {
  private {
    alias UpdateFunction = void delegate(CueInfo info);

    struct CueInfo {
      string position;
      string name;
      long duration;
      SysTime begin;
    }

    StatStorage storage;
    string[] path;

    CueInfo[] cues;
  }

  this(StatStorage storage) {
    super();
    this.storage = storage;
  }

  this(ReportWriter writer, StatStorage storage) {
    super(writer);
    this.storage = storage;
  }

  void update() {
    writer.resetLine;

    foreach(cue; cues) {
      auto currentDuration = Clock.currTime - cue.begin;
      auto diff = cue.duration - currentDuration.total!"seconds";

      writer.write("*[" ~ diff.to!string ~ "s]" ~ cue.name ~ " ");
    }
  }

  void removeCue(string name) {
    cues = cues.filter!(a => a.name == name).array;
  }

  override {
    void begin(ref SuiteResult suite) {
      super.begin(suite);

      path ~= suite.name;
      auto cue = path.join('.');
      auto stat = storage.find(cue);
      auto duration = (stat.end - stat.begin).total!"seconds";

      cues ~= CueInfo(cue, suite.name, duration, Clock.currTime);
      update;
    }

    void end(ref SuiteResult suite) {
      writer.resetLine;
      super.end(suite);

      auto cue = path.join('.');
      path = path[0..$-1];

      removeCue(cue);
    }

    void begin(ref TestResult test) {
      super.begin(test);

      path ~= test.name;
      auto cue = path.join('.');

      auto stat = storage.find(cue);
      auto duration = (stat.end - stat.begin).total!"seconds";

      cues ~= CueInfo(cue, test.name, duration, Clock.currTime);
      update;
    }

    void end(ref TestResult test) {
      writer.resetLine;
      super.end(test);
      auto cue = path.join('.');
      path = path[0..$-1];

      removeCue(cue);
    }

    void begin(ref StepResult step) {}
    void end(ref StepResult test) {}
  }
}

version(unittest) {
  import fluent.asserts;
  import core.thread;
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

  writer.buffer.should.contain("\n  some suite\n*[10s]some suite *[10s]some test");

  Thread.sleep(1.seconds);
  reporter.update();

  writer.buffer.should.contain("\n  some suite\n*[9s]some suite *[9s]some test");

  reporter.end(test);
  reporter.end(suite);

  writer.buffer.should.contain("\n  some suite\n    ✓ some test");

  reporter.update();

  writer.buffer.should.contain("\n  some suite\n    ✓ some test");
}


@("it should print two success tests")
unittest {
  auto storage = new StatStorage;
  auto begin = SysTime.min;
  auto end = begin + 10.seconds;

  storage.values = [ ];

  auto writer = new BufferedWriter;
  auto reporter = new SpecProgressReporter(writer, storage);

  auto suite = SuiteResult("some suite");
  auto test1 = new TestResult("test1");
  test1.status = TestResult.Status.success;

  auto test2 = new TestResult("test2");
  test2.status = TestResult.Status.success;

  reporter.begin(suite);
  reporter.begin(test1);
  reporter.end(test1);

  reporter.begin(test2);
  writer.buffer.should.contain("\n  some suite\n    ✓ test1\n*[0s]test2");

  reporter.update();
  writer.buffer.should.contain("\n  some suite\n    ✓ test1\n*[0s]test2");

  reporter.end(test2);
  reporter.end(suite);

  suite.name = "suite2";
  reporter.begin(suite);
  reporter.begin(test1);

  writer.buffer.should.contain("\n  some suite\n    ✓ test1\n    ✓ test2\n\n  suite2\n*[0s]suite2 *[0s]test1");
}
