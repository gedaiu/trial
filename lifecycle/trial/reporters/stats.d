module trial.reporters.stats;

import std.algorithm;
import std.string;
import std.conv;
import std.exception;
import std.array;

import trial.interfaces;

class StatsReporter : ILifecycleListener {

  void begin() {
  }

  void end(SuiteResult[] result) {

  }
}

string[string] toDurationList(T)(const T[] results) {
  string[string] list;

  foreach(result; results) {
    list[result.name] = result.begin.toISOExtString ~ "," ~ result.end.toISOExtString;

    static if(is(T == SuiteResult)) {
      auto childs = result.tests.toDurationList;
    } else {
      auto childs = result.steps.toDurationList;
    }

    foreach(string name, string value; childs) {
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
  resultList["suite"].should.equal(begin.toISOExtString ~ "," ~ end.toISOExtString);
  resultList["suite.test"].should.equal(begin.toISOExtString ~ "," ~ end.toISOExtString);
  resultList["suite.test.step"].should.equal(begin.toISOExtString ~ "," ~ end.toISOExtString);
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

void createStepByName(T)(ref T step, const string[] path) {
  if(!step.steps.canFind!(a => a.name == path[0])) {
    auto element = new StepResult();
    element.name = path[0];
    step.steps ~= element;
  }

  if(path.length > 1) {
    auto r = step.steps.find!(a => a.name == path[0]);
    enforce(!r.empty, "Can not find step `" ~ path[0] ~ "`");
    r.front.createStepByName(path[1..$]);
  }
}

void createTestByName(ref SuiteResult suite, const string[] path) {
  if(!suite.tests.canFind!(a => a.name == path[0])) {
    auto element = new TestResult(path[0]);
    suite.tests ~= element;
  }

  if(path.length > 1) {
    auto r = suite.tests.find!(a => a.name == path[0]);
    enforce(!r.empty, "Can not find test `" ~ path[0] ~ "`");
    r.front.createStepByName(path[1..$]);
  }
}

void createSuiteByName(ref SuiteResult[] list, const string[] path) {

  if(!list.canFind!(a => a.name == path[0])) {
    SuiteResult element;
    element.name = path[0];
    list ~= element;
  }

  if(path.length > 1) {
    auto r = list.find!(a => a.name == path[0]);
    enforce(!r.empty, "Can not suite find `" ~ path[0] ~ "`");
    r.front.createTestByName(path[1..$]);
  }
}

void setInterval(T)(ref T[] list, string key, SysTime begin, SysTime end, string prefix = "") {
  foreach(ref item; list) {
    if(prefix ~ item.name == key) {
      item.begin = begin;
      item.end = end;

      return;
    }

    if(key.indexOf(prefix ~ item.name) == 0) {
      static if(is(T == SuiteResult)) {
        item.tests.setInterval(key, begin, end, prefix ~ item.name ~ ".");
      }

      static if(is(T == TestResult)) {
        item.steps.setInterval(key, begin, end, prefix ~ item.name ~ ".");
      }

      static if(is(T == StepResult)) {
        item.steps.setInterval(key, begin, end, prefix ~ item.name ~ ".");
      }
    }
  }
}

SuiteResult[] toSuiteList(string[string] data) {
  SuiteResult[] list;

  foreach(string key, value; data) {
    auto pieces = key.split('.');
    list.createSuiteByName(pieces);
  }

  foreach(string key, value; data) {
    auto vals = value.split(",");
    auto begin = SysTime.fromISOExtString(vals[0]);
    auto end = SysTime.fromISOExtString(vals[1]);

    list.setInterval(key, begin, end);
  }

  return list;
}

@("it should convert a string step as hashmap to SuiteResult array")
unittest {
  auto begin = Clock.currTime;
  auto end = begin + 2.seconds;

  string[string] data = ["suite.test.step": begin.toISOExtString ~ "," ~ end.toISOExtString];

  auto result = data.toSuiteList;

  result[0].name.should.equal("suite");
  result[0].tests[0].name.should.equal("test");
  result[0].tests[0].steps[0].name.should.equal("step");

  result[0].tests[0].steps[0].begin.should.equal(begin);
  result[0].tests[0].steps[0].end.should.equal(end);
}

@("it should convert a string step as hashmap to SuiteResult array")
unittest {
  auto begin = Clock.currTime;
  auto end = begin + 2.seconds;

  string[string] data = [
  "suite.test.step1": begin.toISOExtString ~ "," ~ end.toISOExtString,
  "suite.test.step2": begin.toISOExtString ~ "," ~ end.toISOExtString];

  auto result = data.toSuiteList;

  result[0].name.should.equal("suite");
  result.length.should.equal(1);

  result[0].tests[0].name.should.equal("test");
  result[0].tests.length.should.equal(1);

  result[0].tests[0].steps.length.should.equal(2);
  [result[0].tests[0].steps[0].name, result[0].tests[0].steps[1].name].should.contain(["step1", "step2"]);

  result[0].tests[0].steps[0].begin.should.equal(begin);
  result[0].tests[0].steps[0].end.should.equal(end);

  result[0].tests[0].steps[0].begin.should.equal(begin);
  result[0].tests[0].steps[0].end.should.equal(end);
}
