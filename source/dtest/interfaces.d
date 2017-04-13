module dtest.interfaces;

import std.datetime;

interface IStepLifecycleListener {
  void begin(ref Suite, ref Test, ref Step);
  void end(ref Suite, ref Test, ref Step);
}

interface ITestCaseLifecycleListener {
  void begin(ref Suite, ref Test);
  void end(ref Suite, ref Test);
}

interface ISuiteLifecycleListener {
  void begin(ref Suite);
  void end(ref Suite);
}

struct Suite {
  string name;

  SysTime begin;
  SysTime end;

  Test[] tests;
}

struct Step {
  string name;

  SysTime begin;
  SysTime end;

  Step[] steps;
}

struct Test {
  enum Status {
    created, failure, skip, started, success
  }

  string name;
  Status status = Status.created;
  Throwable throwable;

  SysTime begin;
  SysTime end;

  Step[] steps;
}
