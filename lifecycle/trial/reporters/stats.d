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

import trial.interfaces;

struct Stat
{
  string name;
  SysTime begin;
  SysTime end;
  TestResult.Status status = TestResult.Status.unknown;
}

class StatStorage
{
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
    StatStorage storage;
    string[][string] path;
  }

  this(StatStorage storage)
  {
    this.storage = storage;
  }

  this()
  {
    this.storage = new StatStorage;
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
    storage.values ~= Stat(suite ~ "." ~ test.name, test.begin, Clock.currTime, test.status);
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
    auto f = File("trial-stats.csv", "w"); // open for writing
    f.write(storage.toCsv);
  }
}

version (unittest)
{
  import fluent.asserts;
  import std.datetime;
  import std.stdio;
}

@("it should add suite to the storage")
unittest
{
  auto storage = new StatStorage;
  auto stats = new StatsReporter(storage);

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
  auto stats = new StatsReporter(storage);

  SuiteResult suite = SuiteResult("suite");

  auto test = new TestResult("test1");
  test.status = TestResult.Status.success;

  stats.begin(suite);
  stats.begin("suite", test);
  stats.end("suite", test);

  storage.values.length.should.equal(1);

  test.name = "test2";
  test.status = TestResult.Status.failure;
  stats.begin("suite", test);
  stats.end("suite", test);

  storage.values.length.should.equal(2);
  storage.values.map!(a => a.name).array.should.equal(["suite.test1", "suite.test2"]);
  storage.values.map!(a => a.status)
    .array.should.equal([TestResult.Status.success, TestResult.Status.failure]);
  storage.values.map!(a => a.begin).array.should.equal([test.begin, test.begin]);
  storage.values.map!(a => a.end > a.begin).array.should.equal([true, true]);
}

@("it should add steps to the storage")
unittest
{
  auto storage = new StatStorage;
  auto stats = new StatsReporter(storage);

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
      a.end.toISOExtString, a.status.to!string]).map!(a => a.join(',')).join('\n');
}

@("it should convert stat storage to csv")
unittest
{
  auto stats = new StatStorage;
  stats.values = [Stat("1", SysTime.min, SysTime.max), Stat("2", SysTime.min, SysTime.max)];

  stats.toCsv.should.equal("1,-29227-04-19T21:11:54.5224192Z,+29228-09-14T02:48:05.4775807Z,unknown\n"
      ~ "2,-29227-04-19T21:11:54.5224192Z,+29228-09-14T02:48:05.4775807Z,unknown");
}

StatStorage toStatStorage(const(string) data)
{
  auto stat = new StatStorage;

  stat.values = data.split('\n').map!(a => a.split(',')).map!(a => Stat(a[0],
      SysTime.fromISOExtString(a[1]), SysTime.fromISOExtString(a[2]),
      a[3].to!(TestResult.Status))).array;

  return stat;
}

@("it should create stat storage from csv")
unittest
{
  auto storage = ("1,-29227-04-19T21:11:54.5224192Z,+29228-09-14T02:48:05.4775807Z,success\n"
      ~ "2,-29227-04-19T21:11:54.5224192Z,+29228-09-14T02:48:05.4775807Z,unknown").toStatStorage;

  storage.values.length.should.equal(2);
  storage.values[0].name.should.equal("1");
  storage.values[0].begin.should.equal(SysTime.min);
  storage.values[0].end.should.equal(SysTime.max);
  storage.values[0].status.should.equal(TestResult.Status.success);

  storage.values[1].name.should.equal("2");
  storage.values[1].begin.should.equal(SysTime.min);
  storage.values[1].end.should.equal(SysTime.max);
  storage.values[1].status.should.equal(TestResult.Status.unknown);
}

StatStorage statsFromFile(string fileName)
{
  if (!fileName.exists)
  {
    return new StatStorage();
  }

  return fileName.readText.toStatStorage;
}
