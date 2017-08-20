/++
  A module containing the XUnitReporter

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.xunit;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;
import std.file;
import std.path;
import std.uuid;
import std.range;

import trial.interfaces;
import trial.reporters.writer;

private string escapeXUnit(string data) {
  string escapedData = data.dup;

  escapedData = escapedData.replace(`&`, `&amp;`);
  escapedData = escapedData.replace(`"`, `&quot;`);
  escapedData = escapedData.replace(`'`, `&apos;`);
  escapedData = escapedData.replace(`<`, `&lt;`);
  escapedData = escapedData.replace(`>`, `&gt;`);

  return escapedData;
}

/// The XUnit reporter creates a xml containing the test results
class XUnitReporter : ILifecycleListener
{
  void begin(ulong testCount) {
    if(exists("allure")) {
      std.file.rmdirRecurse("allure");
    }
  }

  void update() {}

  void end(SuiteResult[] result)
  {
    if(!exists("xunit")) {
      "xunit".mkdir;
    }

    foreach(item; result) {
      string uuid = randomUUID.toString;
      string xml = `<?xml version="1.0" encoding="UTF-8"?>` ~ "\n"~ `<testsuites>` ~ "\n" ~ XUnitSuiteXml(item, uuid).toString ~ "\n</testsuites>\n";

      std.file.write("xunit/" ~ item.name ~ ".xml", xml);
    }
  }
}

struct XUnitSuiteXml {
  /// The suite result
  SuiteResult result;

  /// The suite id
  string uuid;

  /// Converts the suiteResult to a xml string
  string toString() {
    auto epoch = SysTime.fromUnixTime(0);
    string tests = result.tests.map!(a => XUnitTestXml(a, uuid).toString).array.join("\n");


    auto failures = result.tests.filter!(a => a.status == TestResult.Status.failure).count;
    auto skipped = result.tests.filter!(a => a.status == TestResult.Status.skip).count;
    auto errors = result.tests.filter!(a =>
      a.status != TestResult.Status.success &&
      a.status != TestResult.Status.skip &&
      a.status != TestResult.Status.failure).count;

    if(tests != "") {
      tests = "\n" ~ tests;
    }

    auto xml = `  <testsuite name="` ~ result.name ~ `" errors="` ~ errors.to!string ~ `" skipped="` ~ skipped.to!string ~ `" tests="` ~ result.tests.length.to!string ~ `" failures="` ~ failures.to!string ~ `" time="0" timestamp="` ~ result.begin.toISOExtString ~ `">`
     ~ tests ~ `
  </testsuite>`;

    return xml;
  }
}

version(unittest) {
  import fluent.asserts;
}

/// XUnitTestXml should transform a suite with a success test
unittest
{
  auto epoch = SysTime.fromUnixTime(0);
  auto result = SuiteResult("Test Suite");
  result.begin = Clock.currTime;

  TestResult test = new TestResult("Test");
  test.begin = Clock.currTime;
  test.end = Clock.currTime;
  test.status = TestResult.Status.success;

  result.end = Clock.currTime;

  result.tests = [ test ];

  auto xunit = XUnitSuiteXml(result);

  xunit.toString.should.equal(`  <testsuite name="` ~ result.name.escapeXUnit ~ `" errors="0" skipped="0" tests="1" failures="0" time="0" timestamp="`~result.begin.toISOExtString~`">
      <testcase name="Test">
      </testcase>
  </testsuite>`);
}

/// XUnitTestXml should transform a suite with a failed test
unittest
{
  auto epoch = SysTime.fromUnixTime(0);
  auto result = SuiteResult("Test Suite");
  result.begin = Clock.currTime;

  TestResult test = new TestResult("Test");
  test.begin = Clock.currTime;
  test.end = Clock.currTime;
  test.status = TestResult.Status.failure;

  result.end = Clock.currTime;

  result.tests = [ test ];

  auto xunit = XUnitSuiteXml(result);

  xunit.toString.should.equal(`  <testsuite name="` ~ result.name.escapeXUnit ~ `" errors="0" skipped="0" tests="1" failures="1" time="0" timestamp="`~result.begin.toISOExtString~`">
      <testcase name="Test">
      <failure/>
      </testcase>
  </testsuite>`);
}

/// XUnitTestXml should transform a suite with a skipped test
unittest
{
  auto epoch = SysTime.fromUnixTime(0);
  auto result = SuiteResult("Test Suite");
  result.begin = Clock.currTime;

  TestResult test = new TestResult("Test");
  test.begin = Clock.currTime;
  test.end = Clock.currTime;
  test.status = TestResult.Status.skip;

  result.end = Clock.currTime;

  result.tests = [ test ];

  auto xunit = XUnitSuiteXml(result);

  xunit.toString.should.equal(`  <testsuite name="` ~ result.name.escapeXUnit ~ `" errors="0" skipped="1" tests="1" failures="0" time="0" timestamp="`~result.begin.toISOExtString~`">
      <testcase name="Test">
      <skipped/>
      </testcase>
  </testsuite>`);
}


/// XUnitTestXml should transform a suite with a unknown test
unittest
{
  auto epoch = SysTime.fromUnixTime(0);
  auto result = SuiteResult("Test Suite");
  result.begin = Clock.currTime;

  TestResult test = new TestResult("Test");
  test.begin = Clock.currTime;
  test.end = Clock.currTime;
  test.status = TestResult.Status.unknown;

  result.end = Clock.currTime;

  result.tests = [ test ];

  auto xunit = XUnitSuiteXml(result);

  xunit.toString.should.equal(`  <testsuite name="` ~ result.name.escapeXUnit ~ `" errors="1" skipped="0" tests="1" failures="0" time="0" timestamp="`~result.begin.toISOExtString~`">
      <testcase name="Test">
      <error message="unknown status">unknown</error>
      </testcase>
  </testsuite>`);
}

/// XUnitTestXml should transform an empty suite
unittest
{
  auto epoch = SysTime.fromUnixTime(0);
  auto result = SuiteResult("Test Suite");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;

  auto xunit = XUnitSuiteXml(result);

  xunit.toString.should.equal(`  <testsuite name="` ~ result.name.escapeXUnit ~ `" errors="0" skipped="0" tests="0" failures="0" time="0" timestamp="` ~ result.begin.toISOExtString ~ `">
  </testsuite>`);
}

struct XUnitTestXml {
  ///
  TestResult result;

  ///
  string uuid;

  /// Return the string representation of the test
  string toString() {
    auto time = (result.end -result.begin).total!"msecs";
    string xml = `      <testcase name="` ~ result.name.escapeXUnit ~ `">` ~ "\n";

    if(result.status == TestResult.Status.failure) {
      if(result.throwable !is null) {
        auto lines = result.throwable.msg.split("\n") ~ "no message";

        xml ~= `      <failure message="` ~ lines[0].escapeXUnit ~ `">` ~ result.throwable.to!string.escapeXUnit ~ `</failure>` ~ "\n";
      } else {
        xml ~= `      <failure/>` ~ "\n";
      }
    } else if(result.status == TestResult.Status.skip) {
      xml ~= `      <skipped/>` ~ "\n";
    } else if(result.status != TestResult.Status.success) {
        xml ~= `      <error message="unknown status">` ~ result.status.to!string.escapeXUnit ~ `</error>` ~ "\n";
    }

    xml ~= `      </testcase>`;

    return xml;
  }
}

/// XUnitTestXml should transform a success test
unittest
{
  auto epoch = SysTime.fromUnixTime(0);

  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.success;

  auto allure = XUnitTestXml(result);

  allure.toString.strip.should.equal(`<testcase name="Test">` ~ "\n      </testcase>");
}

/// XUnitTestXml should transform a failing test
unittest
{
  auto epoch = SysTime.fromUnixTime(0);
  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.failure;
  result.throwable = new Exception("message");

  auto xunit = XUnitTestXml(result);
  xunit.toString.strip.should.equal(`<testcase name="Test">` ~ "\n" ~
  `      <failure message="message">` ~ result.throwable.to!string ~ `</failure>` ~ "\n" ~
  `      </testcase>`);
}
