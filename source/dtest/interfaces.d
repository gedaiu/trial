module dtest.interfaces;

import std.datetime;

interface IStepLifecycleListener {
  void begin(ref Step);
  void end(ref Step);
}

interface ITestCaseLifecycleListener {
  void begin(ref Test);
  void end(ref Test);
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
