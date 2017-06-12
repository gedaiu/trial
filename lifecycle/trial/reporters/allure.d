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
import std.file;
import std.uuid;

import trial.interfaces;
import trial.reporters.writer;

private string escape(string data) {
  string escapedData = data.dup;

  escapedData = escapedData.replace(`&`, `&amp;`);
  escapedData = escapedData.replace(`"`, `&quot;`);
  escapedData = escapedData.replace(`'`, `&apos;`);
  escapedData = escapedData.replace(`<`, `&lt;`);
  escapedData = escapedData.replace(`>`, `&gt;`);

  return escapedData;
}

/// The Allure reporter creates a xml containing the test results, the steps
/// and the attachments. http://allure.qatools.ru/
class AllureReporter : ILifecycleListener
{
  void begin(ulong testCount) {}

  void update() {}

  void end(SuiteResult[] result) 
  {
    if(exists("allure")) {
      std.file.rmdirRecurse("allure");
    }

    "allure".mkdir;

    foreach(xml; result.map!(a => AllureSuiteXml(a).toString)) {
      std.file.write("allure/" ~ randomUUID.toString ~ "-testsuite.xml", xml);
    }
  }
}

struct AllureSuiteXml {
  /// The suite result
  SuiteResult result;

  /// The allure version
  const string allureVersion = "1.5.2";

  /// Converts the suiteResult to a xml string
  string toString() {
    auto epoch = SysTime.fromUnixTime(0);
    string tests = result.tests.map!(a => AllureTestXml(a).toString).array.join("\n");

    if(tests != "") {
      tests = "\n" ~ tests;
    }

    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:test-suite start="` ~ (result.begin - epoch).total!"msecs".to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs".to!string ~ `" version="` ~ this.allureVersion ~ `" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
    <name>` ~ result.name.escape ~ `</name>
    <title>` ~ result.name.escape ~ `</title>
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
  auto epoch = SysTime.fromUnixTime(0);
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
<ns2:test-suite start="` ~ (result.begin - epoch).total!"msecs".to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs".to!string ~ `" version="1.5.2" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
    <name>` ~ result.name ~ `</name>
    <title>` ~ result.name ~ `</title>
    <test-cases>
        <test-case start="` ~ (test.begin - epoch).total!"msecs".to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs".to!string ~ `" status="passed">
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
  auto epoch = SysTime.fromUnixTime(0);
  SuiteResult result;
  result.name = "Test Suite";
  result.begin = Clock.currTime;
  result.end = Clock.currTime;

  auto allure = AllureSuiteXml(result);

  allure.toString.should.equal(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:test-suite start="` ~ (result.begin - epoch).total!"msecs".to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs".to!string ~ `" version="1.5.2" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
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
        return "failed";

      case TestResult.Status.skip:
        return "canceled";

      case TestResult.Status.success:
        return "passed";

      default:
        return "unknown";
    }
  }

  string toString() {
    auto epoch = SysTime.fromUnixTime(0);
    auto start = (result.begin - epoch).total!"msecs";
    auto stop = (result.end - epoch).total!"msecs";

    string xml = `        <test-case start="` ~ start.to!string ~ `" stop="` ~ stop.to!string ~ `" status="` ~ allureStatus ~ `">` ~ "\n";
    xml ~= `            <name>` ~ result.name.escape ~ `</name>` ~ "\n";

    if(result.throwable !is null) {
      xml ~= `            <failure>
                <message>` ~ result.throwable.msg.escape ~ `</message>
                <stack-trace>` ~ result.throwable.to!string.escape ~ `</stack-trace>
            </failure>` ~ "\n";
    }

    xml ~= `        </test-case>`;

    return xml;
  }
}

@("AllureTestXml should transform a success test")
unittest 
{
  auto epoch = SysTime.fromUnixTime(0);

  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.success;

  auto allure = AllureTestXml(result);

  allure.toString.should.equal(
`        <test-case start="` ~ (result.begin - epoch).total!"msecs".to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs".to!string ~ `" status="passed">
            <name>Test</name>
        </test-case>`);
}

@("AllureTestXml should transform a failing test")
unittest 
{
  auto epoch = SysTime.fromUnixTime(0);
  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.failure;
  result.throwable = new Exception("message");

  auto allure = AllureTestXml(result);

  allure.toString.should.equal(
`        <test-case start="` ~ (result.begin - epoch).total!"msecs".to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs".to!string ~ `" status="broken">
            <name>Test</name>
            <failure>
                <message>message</message>
                <stack-trace>object.Exception@lifecycle/trial/reporters/allure.d(` ~ result.throwable.line.to!string ~ `): message</stack-trace>
            </failure>
        </test-case>`);
}