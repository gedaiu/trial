module dtest.runner;

import std.stdio;
import std.datetime;

import dtest.discovery;
import dtest.interfaces;

struct SuiteRunner {
  Suite result;

  private {
    TestCase[] tests;
  }

  this(string name, TestCase[string] testCases) {
    result.name = name;

    foreach(string key, testCase; testCases) {
      tests ~= testCase;
      result.tests ~= Test(testCase.name);
    }
  }

  void start() {
    result.begin = Clock.currTime;

    foreach(size_t i, ref test; tests) {
      result.tests[i].begin = Clock.currTime;
      result.tests[i].status = Test.Status.success;
      result.tests[i].end = Clock.currTime;
    }

    result.end = Clock.currTime;
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
