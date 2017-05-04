module trial.reporters.stats;

import std.algorithm;
import std.string;
import std.conv;

import trial.interfaces;

class StatsReporter : ILifecycleListener {

  void begin() {
  }

  void end(SuiteResult[] result) {

  }
}

long[string] toDurationList(T)(const T[] results) pure {
  long[string] list;

  foreach(result; results) {
    list[result.name] = (result.end - result.begin).total!"nsecs";

    static if(is(T == SuiteResult)) {
      auto childs = result.tests.toDurationList;
    } else {
      auto childs = result.steps.toDurationList;
    }

    foreach(string name, long value; childs) {
      list[result.name ~ "." ~ name] = value;
    }
  }

  return list;
}

version(unittest) {
  import fluent.asserts;
  import std.datetime;
  import std.stdio;
}

@("it should be able to convert a suite result to a string hashmap")
unittest {
  auto begin = Clock.currTime;
  auto end = begin + 2.seconds;

  auto testResult = new TestResult("test");
  testResult.begin = begin;
  testResult.end = end;

  auto stepResult = new StepResult;
  stepResult.name = "step";
  stepResult.begin = begin;
  stepResult.end = end;

  testResult.steps = [ stepResult ];

  auto suiteResult = SuiteResult("suite", begin, end, [ testResult ]);
  SuiteResult[] result = [ suiteResult ];

  auto resultList = result.toDurationList;

  resultList.length.should.equal(3);
  resultList["suite"].should.equal(2_000_000_000);
  resultList["suite.test"].should.equal(2_000_000_000);
  resultList["suite.test.step"].should.equal(2_000_000_000);
}

string[string] toResultList(const SuiteResult[] results) pure {
  string[string] list;

  foreach(result; results) {
    foreach(test; result.tests) {
      list[result.name ~ "." ~ test.name] = test.status.to!string;
    }
  }

  return list;
}

@("it should be able to convert tests results to a string hashmap")
unittest {
  auto begin = Clock.currTime;
  auto end = begin + 2.seconds;

  auto testResult = new TestResult("test");
  testResult.begin = begin;
  testResult.end = end;

  auto suiteResult = SuiteResult("suite", begin, end, [ testResult ]);
  SuiteResult[] result = [ suiteResult ];

  auto resultList = result.toResultList;

  resultList.length.should.equal(1);
  resultList["suite.test"].should.equal("created");
}
