module dtest.interfaces;

import std.datetime;

interface ILifecycleListener {
  void begin();
  void end(SuiteResult[]);
}

interface IStepLifecycleListener {
  void begin(ref StepResult);
  void end(ref StepResult);
}

interface ITestCaseLifecycleListener {
  void begin(ref TestResult);
  void end(ref TestResult);
}

interface ISuiteLifecycleListener {
  void begin(ref SuiteResult);
  void end(ref SuiteResult);
}

struct SuiteResult {
  string name;

  SysTime begin;
  SysTime end;

  TestResult[] tests;
}

class StepResult {
  string name;

  SysTime begin;
  SysTime end;

  StepResult[] steps;
}

class TestResult : StepResult {
  enum Status {
    created, failure, skip, started, success
  }

  Status status = Status.created;
  Throwable throwable;

  this(string name) {
    this.name = name;
  }
}
