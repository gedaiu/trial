/++
  A module containing the SpecProgressReporter

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
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

/// A flavour of the "spec" reporter that show the progress of long tests. This works well with the
/// parallel runner. If you are using the stats reporters, you will see a countdown for how long
/// you need to wait until the test is finished.
class SpecProgressReporter : SpecReporter, ISuiteLifecycleListener, ILifecycleListener {
  private {
    alias UpdateFunction = void delegate(CueInfo info);

    struct CueInfo {
      string id;
      string name;
      long duration;
      SysTime begin;
    }

    size_t oldTextLength;
    StatStorage storage;
    string[] path;

    CueInfo[] cues;
  }

  this(StatStorage storage) {
    super();
    this.storage = storage;
    writer.writeln("");
  }

  this(ReportWriter writer, StatStorage storage) {
    super(writer);
    this.storage = storage;
    writer.writeln("");
  }

  void clearProgress() {
    writer.goTo(1);
    writer.write("\n" ~ " ".replicate(oldTextLength));
    writer.goTo(1);
    oldTextLength = 0;
  }

  void begin(ulong) {}
  void end(SuiteResult[]) {}
  void update() {
    writer.hideCursor;
    auto now = Clock.currTime;
    auto progress = cues.map!(cue => "*[" ~ (cue.duration - (now - cue.begin).total!"seconds").to!string ~ "s]" ~ cue.name).join(" ").to!string;

    auto spaces = "";

    if(oldTextLength > progress.length) {
      spaces = " ".replicate(oldTextLength - progress.length);
    }

    writer.goTo(1);
    writer.write("\n" ~ progress ~ spaces ~ " ");

    oldTextLength = progress.length;
    writer.showCursor;
  }

  void removeCue(string id) {
    cues = cues.filter!(a => a.id != id).array;
  }

  void begin(ref SuiteResult suite) {
    auto stat = storage.find(suite.name);
    auto duration = (stat.end - stat.begin).total!"seconds";

    cues ~= CueInfo(suite.name, suite.name, duration, Clock.currTime);
    update;
  }

  void end(ref SuiteResult suite) {
    removeCue(suite.name);
    update;
  }

  override {
    void begin(string suite, ref TestResult test) {
      super.begin(suite, test);

      auto stat = storage.find(suite ~ "." ~ test.name);
      auto duration = (stat.end - stat.begin).total!"seconds";

      cues ~= CueInfo(suite ~ "." ~ test.name, test.name, duration, Clock.currTime);
      update;
    }

    void end(string suite, ref TestResult test) {
      clearProgress;
      super.end(suite, test);
      removeCue(suite ~ "." ~ test.name);
      writer.writeln("");
      update;
    }
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

  reporter.begin(suite);
  reporter.begin("some suite", test);

  writer.buffer.should.equal("\n*[10s]some suite *[10s]some test ");

  Thread.sleep(1.seconds);
  reporter.update();

  writer.buffer.should.equal("\n*[9s]some suite *[9s]some test   ");

  test.status = TestResult.Status.success;
  reporter.end("some suite", test);

  writer.buffer.should.equal("\n  some suite                     \n    ✓ some test\n\n*[9s]some suite ");
  reporter.end(suite);

  writer.buffer.should.equal("\n  some suite                     \n    ✓ some test\n\n                ");

  reporter.update();

  writer.buffer.should.equal("\n  some suite                     \n    ✓ some test\n\n                ");
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
  reporter.begin("some suite", test1);
  reporter.end("some suite", test1);

  reporter.begin("some suite", test2);
  writer.buffer.should.equal("\n  some suite               \n    ✓ test1\n\n*[0s]some suite *[0s]test2 ");

  reporter.update();
  writer.buffer.should.equal("\n  some suite               \n    ✓ test1\n\n*[0s]some suite *[0s]test2 ");

  reporter.end("some suite", test2);

  writer.buffer.should.equal("\n  some suite               \n    ✓ test1\n    ✓ test2\n                           \n*[0s]some suite ");
  reporter.end(suite);

  suite.name = "suite2";
  reporter.begin(suite);
  reporter.begin("suite2", test1);
  reporter.end("suite2", test1);

  writer.buffer.should.equal(
    "\n  some suite               \n" ~
    "    ✓ test1\n"~
    "    ✓ test2\n"~
    "                           \n"~
    "  suite2               \n"~
    "    ✓ test1\n\n"~
    "*[0s]suite2 ");
}
