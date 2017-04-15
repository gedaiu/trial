module dtest.runner;

import std.stdio;
import std.algorithm;
import std.datetime;
import std.range;
import std.traits;

import dtest.discovery;
import dtest.interfaces;

struct LifeCycleListeners {
  private {
    ISuiteLifecycleListener[] suiteListeners;
    ITestCaseLifecycleListener[] testListeners;
  }

  void add(T)(T listener) {

    static if(!is(CommonType!(ISuiteLifecycleListener, T) == void)) {
      suiteListeners ~= listener;
    }

    static if(!is(CommonType!(ITestCaseLifecycleListener, T) == void)) {
      testListeners ~= listener;
    }
  }

  void begin(ref Suite suite) {
    suiteListeners.each!(a => a.begin(suite));
  }

  void end(ref Suite suite) {
    suiteListeners.each!(a => a.end(suite));
  }

  void begin(ref Test test) {
    testListeners.each!(a => a.begin(test));
  }

  void end(ref Test test) {
    testListeners.each!(a => a.end(test));
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
    result.end = Clock.currTime;

    listeners.begin(result);

    tests
      .map!(a => TestRunner(a, listeners))
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
    LifeCycleListeners listeners;
  }

  this(const TestCase testCase, LifeCycleListeners listeners) {
    this.testCase = testCase;
    this.listeners = listeners;
  }

  Test start() {
    Test test;

    test.name = testCase.name;
    test.begin = Clock.currTime;
    test.end = Clock.currTime;
    test.status = Test.Status.started;

    listeners.begin(test);
    try {
      testCase.func();
      test.status = Test.Status.success;
    } catch(Throwable t) {
      test.status = Test.Status.failure;
      test.throwable = t;
    }

    test.end = Clock.currTime;

    listeners.end(test);
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
