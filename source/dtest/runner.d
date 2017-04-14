module dtest.runner;

import std.stdio;
import std.algorithm;
import std.datetime;

import dtest.discovery;
import dtest.interfaces;

struct SuiteRunner {
  Suite result;

  private {
    TestCase[] tests;

    ISuiteLifecycleListener[] suiteListeners;
  }

  this(string name, TestCase[string] testCases) {
    result.name = name;

    foreach(string key, testCase; testCases) {
      tests ~= testCase;
      result.tests ~= Test(testCase.name);
    }
  }

  void addListener(ISuiteLifecycleListener listener) {
    suiteListeners ~= listener;
  }

  private {
    void notifyBegin() {
      suiteListeners.each!(a => a.begin(result) );
    }

    void notifyEnd() {
      suiteListeners.each!(a => a.end(result) );
    }
  }

  void start() {
    result.begin = Clock.currTime;

    notifyBegin();

    foreach(size_t i, ref test; tests) {
      result.tests[i].begin = Clock.currTime;

      try {
        tests[i].func();
        result.tests[i].status = Test.Status.success;
      } catch(Throwable t) {
        result.tests[i].status = Test.Status.failure;
        result.tests[i].throwable = t;
      }

      result.tests[i].end = Clock.currTime;
    }

    result.end = Clock.currTime;

    notifyEnd();
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
