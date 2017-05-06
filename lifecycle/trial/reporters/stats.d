module trial.reporters.stats;

import std.algorithm;
import std.string;
import std.conv;
import std.exception;
import std.array;

import trial.interfaces;

struct Stat {
  string name;
  SysTime begin;
  SysTime end;
  TestResult.Status status = TestResult.Status.unknown;
}

class StatStorage {
  Stat[] values;
}

class StatsReporter : ITestCaseLifecycleListener, ISuiteLifecycleListener, IStepLifecycleListener {
  private {
    StatStorage storage;
    string[] path;
  }

  this(StatStorage storage) {
    this.storage = storage;
  }

  private {
    auto lastItem() {
      enforce(path.length > 0, "There is no defined path");
      return path[path.length - 1];
    }
  }

  void begin(ref SuiteResult suite) {
    path ~= suite.name;
  }

  void end(ref SuiteResult suite) {
    enforce(lastItem == suite.name, "Invalid suite name");
    storage.values ~= Stat(path.join('.'), suite.begin, Clock.currTime);
    path = path[0..$-1];
  }

  void begin(ref TestResult test) {
    path ~= test.name;
  }

  void end(ref TestResult test) {
    enforce(lastItem == test.name, "Invalid test name");
    storage.values ~= Stat(path.join('.'), test.begin, Clock.currTime, test.status);
    path = path[0..$-1];
  }

  void begin(ref StepResult step) {
    path ~= step.name;
  }

  void end(ref StepResult step) {
    enforce(lastItem == step.name, "Invalid step name");
    storage.values ~= Stat(path.join('.'), step.begin, Clock.currTime);
    path = path[0..$-1];
  }
}

version(unittest) {
  import fluent.asserts;
  import std.datetime;
  import std.stdio;
}

@("it should add suite to the storage")
unittest {
  auto storage = new StatStorage;
  auto stats = new StatsReporter(storage);

  SuiteResult suite;
  suite.name = "suite1";

  stats.begin(suite);
  stats.end(suite);

  storage.values.length.should.equal(1);

  suite.name = "suite2";
  stats.begin(suite);
  stats.end(suite);

  storage.values.length.should.equal(2);
  storage.values.map!(a => a.name).array.should.equal([ "suite1", "suite2" ]);
  storage.values.map!(a => a.status).array.should.equal([ TestResult.Status.unknown, TestResult.Status.unknown ]);
  storage.values.map!(a => a.begin).array.should.equal([ suite.begin, suite.begin ]);
  storage.values.map!(a => a.end > a.begin).array.should.equal([ true, true ]);
}

@("it should add tests to the storage")
unittest {
  auto storage = new StatStorage;
  auto stats = new StatsReporter(storage);

  SuiteResult suite;
  suite.name = "suite";

  auto test = new TestResult("test1");
  test.status = TestResult.Status.success;

  stats.begin(suite);
  stats.begin(test);
  stats.end(test);

  storage.values.length.should.equal(1);

  test.name = "test2";
  test.status = TestResult.Status.failure;
  stats.begin(test);
  stats.end(test);

  storage.values.length.should.equal(2);
  storage.values.map!(a => a.name).array.should.equal([ "suite.test1", "suite.test2" ]);
  storage.values.map!(a => a.status).array.should.equal([ TestResult.Status.success, TestResult.Status.failure ]);
  storage.values.map!(a => a.begin).array.should.equal([ test.begin, test.begin ]);
  storage.values.map!(a => a.end > a.begin).array.should.equal([ true, true ]);
}

@("it should add steps to the storage")
unittest {
  auto storage = new StatStorage;
  auto stats = new StatsReporter(storage);

  SuiteResult suite;
  suite.name = "suite";

  auto test = new TestResult("test");
  auto step = new StepResult;
  step.name = "step1";
  step.begin = Clock.currTime;

  stats.begin(suite);
  stats.begin(test);
  stats.begin(step);
  stats.end(step);

  storage.values.length.should.equal(1);

  step.name = "step2";
  stats.begin(step);
  stats.end(step);

  storage.values.length.should.equal(2);
  storage.values.map!(a => a.name).array.should.equal([ "suite.test.step1", "suite.test.step2" ]);
  storage.values.map!(a => a.status).array.should.equal([ TestResult.Status.unknown, TestResult.Status.unknown ]);
  storage.values.map!(a => a.begin).array.should.equal([ step.begin, step.begin ]);
  storage.values.map!(a => a.end > a.begin).array.should.equal([ true, true ]);
}
