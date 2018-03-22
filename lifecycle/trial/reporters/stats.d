/++
  A module containing the StatsReporter

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.stats;

import std.algorithm;
import std.string;
import std.conv;
import std.exception;
import std.array;
import std.datetime;
import std.stdio;
import std.file;
import std.path;

import trial.runner;
import trial.interfaces;

version (Have_fluent_asserts) {
  version = Have_fluent_asserts_core;
}

///
struct Stat
{
  ///
  string name;
  ///
  SysTime begin;
  ///
  SysTime end;
  ///
  TestResult.Status status = TestResult.Status.unknown;
  ///
  SourceLocation location;
}

///
class StatStorage
{
  ///
  Stat[] values;
}

Stat find(StatStorage storage, const(string) name)
{
  auto res = storage.values.filter!(a => a.name == name);

  if (res.empty)
  {
    return Stat("", SysTime.min, SysTime.min);
  }

  return res.front;
}

/// The stats reporter creates a csv file with the duration and the result of all your steps and tests.
/// It's usefull to use it with other reporters, like spec progress.
class StatsReporter : ILifecycleListener, ITestCaseLifecycleListener,
  ISuiteLifecycleListener, IStepLifecycleListener
{
  private
  {
    immutable string destination;
    StatStorage storage;
    string[][string] path;
  }

  this(StatStorage storage, string destination)
  {
    this.storage = storage;
    this.destination = destination;
  }

  this(string destination)
  {
    this(new StatStorage, destination);
  }

  private
  {
    auto lastItem(string key)
    {
      enforce(path[key].length > 0, "There is no defined path");
      return path[key][path.length - 1];
    }
  }

  void update()
  {
  }

  void begin(ref SuiteResult suite)
  {
  }

  void end(ref SuiteResult suite)
  {
    storage.values ~= Stat(suite.name, suite.begin, Clock.currTime);
  }

  void begin(string suite, ref TestResult test)
  {
  }

  void end(string suite, ref TestResult test)
  {
    storage.values ~= Stat(suite ~ "." ~ test.name, test.begin, Clock.currTime, test.status, SourceLocation(test.fileName, test.line));
  }

  void begin(string suite, string test, ref StepResult step)
  {
    string key = suite ~ "." ~ test;
    path[key] ~= step.name;
  }

  void end(string suite, string test, ref StepResult step)
  {
    string key = suite ~ "." ~ test;

    enforce(lastItem(key) == step.name, "Invalid step name");
    storage.values ~= Stat(key ~ "." ~ path[key].join('.'), step.begin, Clock.currTime);
    path[key] = path[key][0 .. $ - 1];
  }

  void begin(ulong)
  {
  }

  void end(SuiteResult[])
  {
    auto parent = buildPath(pathSplitter(destination).array[0..$-1]);

    if(parent != "" && !parent.exists) {
      mkdirRecurse(parent);
    }

    std.file.write(destination, storage.toCsv);

    auto attachment = const Attachment("stats", destination, "text/csv");

    if(LifeCycleListeners.instance !is null) {
      LifeCycleListeners.instance.attach(attachment);
    }
  }
}

version (unittest)
{
  version(Have_fluent_asserts_core) {
    import fluent.asserts;
    import std.datetime;
    import std.stdio;
  }
}

/// It should write the stats to the expected path
unittest {
  scope(exit) {
    if(exists("destination.csv")) {
      std.file.remove("destination.csv");
    }
  }

  auto stats = new StatsReporter("destination.csv");
  stats.end([]);

  "destination.csv".exists.should.equal(true);
}

@("it should add suite to the storage")
unittest
{
  auto storage = new StatStorage;
  auto stats = new StatsReporter(storage, "trial-stats.csv");

  SuiteResult suite = SuiteResult("suite1");

  stats.begin(suite);
  stats.end(suite);

  storage.values.length.should.equal(1);

  suite.name = "suite2";
  stats.begin(suite);
  stats.end(suite);

  storage.values.length.should.equal(2);
  storage.values.map!(a => a.name).array.should.equal(["suite1", "suite2"]);
  storage.values.map!(a => a.status)
    .array.should.equal([TestResult.Status.unknown, TestResult.Status.unknown]);
  storage.values.map!(a => a.begin).array.should.equal([suite.begin, suite.begin]);
  storage.values.map!(a => a.end > a.begin).array.should.equal([true, true]);
}

@("it should add tests to the storage")
unittest
{
  auto storage = new StatStorage;
  auto stats = new StatsReporter(storage, "trial-stats.csv");

  SuiteResult suite = SuiteResult("suite");

  auto test = new TestResult("test1");
  test.fileName = "file1.d";
  test.line = 11;
  test.status = TestResult.Status.success;

  stats.begin(suite);
  stats.begin("suite", test);
  stats.end("suite", test);

  storage.values.length.should.equal(1);

  test.name = "test2";
  test.status = TestResult.Status.failure;
  test.fileName = "file2.d";
  test.line = 22;

  stats.begin("suite", test);
  stats.end("suite", test);

  storage.values.length.should.equal(2);
  storage.values.map!(a => a.name).array.should.equal(["suite.test1", "suite.test2"]);
  storage.values.map!(a => a.status).array.should.equal([TestResult.Status.success, TestResult.Status.failure]);
  storage.values.map!(a => a.begin).array.should.equal([test.begin, test.begin]);
  storage.values.map!(a => a.end > a.begin).array.should.equal([true, true]);
  storage.values.map!(a => a.location.fileName).array.should.equal(["file1.d", "file2.d"]);
  storage.values.map!(a => a.location.line).array.should.equal([11, 22].to!(size_t[]));
}

@("it should add steps to the storage")
unittest
{
  auto storage = new StatStorage;
  auto stats = new StatsReporter(storage, "trial-stats.csv");

  SuiteResult suite = SuiteResult("suite");

  auto test = new TestResult("test");
  auto step = new StepResult;
  step.name = "step1";
  step.begin = Clock.currTime;

  stats.begin(suite);
  stats.begin("suite", test);
  stats.begin("suite", "test", step);
  stats.end("suite", "test", step);

  storage.values.length.should.equal(1);

  step.name = "step2";
  stats.begin("suite", "test", step);
  stats.end("suite", "test", step);

  storage.values.length.should.equal(2);
  storage.values.map!(a => a.name).array.should.equal(["suite.test.step1", "suite.test.step2"]);
  storage.values.map!(a => a.status)
    .array.should.equal([TestResult.Status.unknown, TestResult.Status.unknown]);
  storage.values.map!(a => a.begin).array.should.equal([step.begin, step.begin]);
  storage.values.map!(a => a.end > a.begin).array.should.equal([true, true]);
}

string toCsv(const(StatStorage) storage)
{
  return storage.values.map!(a => [a.name, a.begin.toISOExtString,
      a.end.toISOExtString, a.status.to!string, a.location.fileName, a.location.line.to!string]).map!(a => a.join(',')).join('\n');
}

@("it should convert stat storage to csv")
unittest
{
  auto stats = new StatStorage;
  stats.values = [Stat("1", SysTime.min, SysTime.max), Stat("2", SysTime.min, SysTime.max, TestResult.Status.success, SourceLocation("file.d", 2))];

  stats.toCsv.should.equal("1,-29227-04-19T21:11:54.5224192Z,+29228-09-14T02:48:05.4775807Z,unknown,,0\n"
      ~ "2,-29227-04-19T21:11:54.5224192Z,+29228-09-14T02:48:05.4775807Z,success,file.d,2");
}

StatStorage toStatStorage(const(string) data)
{
  auto stat = new StatStorage;

  stat.values = data
    .split('\n')
    .map!(a => a.split(','))
    .filter!(a => a.length == 6)
    .map!(a =>
      Stat(a[0],
      SysTime.fromISOExtString(a[1]),
      SysTime.fromISOExtString(a[2]),
      a[3].to!(TestResult.Status),
      SourceLocation(a[4], a[5].to!size_t)))
    .array;

  return stat;
}

@("it should create stat storage from csv")
unittest
{
  auto storage = ("1,-29227-04-19T21:11:54.5224192Z,+29228-09-14T02:48:05.4775807Z,success,,0\n"
      ~ "2,-29227-04-19T21:11:54.5224192Z,+29228-09-14T02:48:05.4775807Z,unknown,file.d,12").toStatStorage;

  storage.values.length.should.equal(2);
  storage.values[0].name.should.equal("1");
  storage.values[0].begin.should.equal(SysTime.min);
  storage.values[0].end.should.equal(SysTime.max);
  storage.values[0].status.should.equal(TestResult.Status.success);
  storage.values[0].location.fileName.should.equal("");
  storage.values[0].location.line.should.equal(0);

  storage.values[1].name.should.equal("2");
  storage.values[1].begin.should.equal(SysTime.min);
  storage.values[1].end.should.equal(SysTime.max);
  storage.values[1].status.should.equal(TestResult.Status.unknown);
  storage.values[1].location.fileName.should.equal("file.d");
  storage.values[1].location.line.should.equal(12);
}

StatStorage statsFromFile(string fileName)
{
  if (!fileName.exists)
  {
    return new StatStorage();
  }

  return fileName.readText.toStatStorage;
}
