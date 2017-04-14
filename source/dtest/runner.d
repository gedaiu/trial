module dtest.runner;

import std.stdio;
import std.algorithm;
import std.datetime;
import std.range;

import dtest.discovery;
import dtest.interfaces;

struct LifeCycleListeners {
  private {
    ISuiteLifecycleListener[] suiteListeners;
    ITestCaseLifecycleListener[] testListeners;
  }

  void add(ISuiteLifecycleListener listener) {
    suiteListeners ~= listener;
  }

  void add(ITestCaseLifecycleListener listener) {
    testListeners ~= listener;
  }

  void begin(ref Suite suite) {
    suiteListeners.each!(a => a.begin(suite));
  }

  void end(ref Suite suite) {
    suiteListeners.each!(a => a.end(suite));
  }
}


struct SuiteRunner {
  Suite result;

  private {
    TestCase[] tests;
  }

  LifeCycleListeners listeners;

  this(string name, TestCase[string] testCases) {
    result.name = name;

    tests = testCases.values;
    result.tests = tests.map!(a => Test(a.name)).array;
  }

  void start() {
    result.begin = Clock.currTime;

    listeners.begin(result);

    tests
      .map!(a => TestRunner(a))
      .map!(a => a.start)
      .enumerate
      .each!(a => result.tests[a[0]] = a[1]);

    result.end = Clock.currTime;

    listeners.end(result);
  }
}

struct TestRunner {

  private {
    const TestCase testCase;
  }

  this(const TestCase testCase) {
    this.testCase = testCase;
  }

  Test start() {
    Test test;

    test.begin = Clock.currTime;

    try {
      testCase.func();
      test.status = Test.Status.success;
    } catch(Throwable t) {
      test.status = Test.Status.failure;
      test.throwable = t;
    }

    test.end = Clock.currTime;

    return test;
  }
}

void runTests(TestDiscovery testDiscovery) {

  foreach(string moduleName, testCases; testDiscovery.testCases) {
    moduleName.writeln;

    foreach(string key, testCase; testCases) {
      testCase.name.writeln;

      try {
          testCase.func();
      } catch(Throwable t) {
          t.writeln;
      }
    }
  }
}
