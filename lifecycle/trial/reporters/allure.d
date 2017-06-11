/++
  A module containing the AllureReporter

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.allure;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;

import trial.interfaces;
import trial.reporters.writer;

/// The Allure reporter creates a xml containing the test results, the steps
/// and the attachments. http://allure.qatools.ru/
class AllureReporter
{

}

struct AllureSuiteXml {
  /// The suite result
  SuiteResult result;

  /// The allure version
  const string allureVersion = "1.5.2";

  /// Converts the suiteResult to a xml string
  string toString() {
    string tests = result.tests.map!(a => AllureTestXml(a).toString).array.join("\n");

    if(tests != "") {
      tests = "\n" ~ tests;
    }

    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:test-suite start="` ~ result.begin.toUnixTime.to!string ~ `" stop="` ~ result.end.toUnixTime.to!string ~ `" version="` ~ this.allureVersion ~ `" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
    <name>` ~ result.name ~ `</name>
    <title>` ~ result.name ~ `</title>
    <test-cases>`
     ~ tests ~ `
    </test-cases>
    <labels>
        <label name="framework" value="Trial"/>
        <label name="language" value="D"/>
    </labels>
</ns2:test-suite>`;
  }
}

version(unittest) {
  import fluent.asserts;
}

@("AllureSuiteXml should transform an empty suite")
unittest 
{
  SuiteResult result;
  result.name = "Test Suite";
  result.begin = Clock.currTime;

  TestResult test = new TestResult("Test");
  test.begin = Clock.currTime;
  test.end = Clock.currTime;
  test.status = TestResult.Status.success;

  result.end = Clock.currTime;

  result.tests = [ test ];

  auto allure = AllureSuiteXml(result);

  allure.toString.should.equal(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:test-suite start="` ~ result.begin.toUnixTime.to!string ~ `" stop="` ~ result.end.toUnixTime.to!string ~ `" version="1.5.2" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
    <name>` ~ result.name ~ `</name>
    <title>` ~ result.name ~ `</title>
    <test-cases>
        <test-case start="` ~ test.begin.toUnixTime.to!string ~ `" stop="` ~ test.end.toUnixTime.to!string ~ `" status="passed">
            <name>Test</name>
        </test-case>
    </test-cases>
    <labels>
        <label name="framework" value="Trial"/>
        <label name="language" value="D"/>
    </labels>
</ns2:test-suite>`);
}

@("AllureSuiteXml should transform a suite with a success test")
unittest 
{
  SuiteResult result;
  result.name = "Test Suite";
  result.begin = Clock.currTime;
  result.end = Clock.currTime;

  auto allure = AllureSuiteXml(result);

  allure.toString.should.equal(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:test-suite start="` ~ result.begin.toUnixTime.to!string ~ `" stop="` ~ result.end.toUnixTime.to!string ~ `" version="1.5.2" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
    <name>` ~ result.name ~ `</name>
    <title>` ~ result.name ~ `</title>
    <test-cases>
    </test-cases>
    <labels>
        <label name="framework" value="Trial"/>
        <label name="language" value="D"/>
    </labels>
</ns2:test-suite>`);
}

struct AllureTestXml {
  ///
  TestResult result;

  /// Converts a test result to allure status
  string allureStatus() {
    switch(result.status) {
      case TestResult.Status.created:
        return "canceled";

      case TestResult.Status.failure:
        return "broken";

      case TestResult.Status.skip:
        return "canceled";

      case TestResult.Status.success:
        return "passed";

      default:
        return "broken";
    }
  }

  string toString() {
    string xml = `        <test-case start="` ~ result.begin.toUnixTime.to!string ~ `" stop="` ~ result.end.toUnixTime.to!string ~ `" status="` ~ allureStatus ~ `">` ~ "\n";
    xml ~= `            <name>Test</name>` ~ "\n";

    if(result.throwable !is null) {
      xml ~= `            <failure>
                <message>` ~ result.throwable.msg ~ `</message>
                <stack-trace>` ~ result.throwable.to!string ~ `</stack-trace>
            </failure>` ~ "\n";
    }

    xml ~= `        </test-case>`;

    return xml;
  }
}

@("AllureTestXml should transform a success test")
unittest 
{
  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.success;

  auto allure = AllureTestXml(result);

  allure.toString.should.equal(
`        <test-case start="` ~ result.begin.toUnixTime.to!string ~ `" stop="` ~ result.end.toUnixTime.to!string ~ `" status="passed">
            <name>Test</name>
        </test-case>`);
}

@("AllureTestXml should transform a failing test")
unittest 
{
  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.failure;
  result.throwable = new Exception("message");

  auto allure = AllureTestXml(result);

  allure.toString.should.equal(
`        <test-case start="` ~ result.begin.toUnixTime.to!string ~ `" stop="` ~ result.end.toUnixTime.to!string ~ `" status="broken">
            <name>Test</name>
            <failure>
                <message>message</message>
                <stack-trace>object.Exception@lifecycle/trial/reporters/allure.d(` ~ result.throwable.line.to!string ~ `): message</stack-trace>
            </failure>
        </test-case>`);
}