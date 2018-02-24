/++
  A module containing the HtmlReporter

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.html;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;
import std.file;
import std.path;

import trial.interfaces;
import trial.reporters.writer;

/// The "html" reporter outputs a hierarchical HTML body representation of your tests.
class HtmlReporter : ILifecycleListener
{
  private
  {
    string trialCss = import("assets/trial.css");
    bool success = true;
    immutable string destination;
  }

  this(string destination)
  {
    this.destination = destination;
  }

  void begin(ulong)
  {
  }

  void update()
  {
  }

  void end(SuiteResult[] results)
  {
    string content = import("templates/htmlReporter.html");
    string trialJs = import("assets/trial.js");

    auto assets = buildPath(destination.dirName, "assets");

    if(!destination.exists) {
      mkdirRecurse(destination);
    }

    if(!assets.exists) {
      mkdirRecurse(assets);
    }

    std.file.write(destination, content.replace("{testResult}", "[" ~ results.map!(a => a.toString).join(",") ~ "]"));
    std.file.write(buildPath(assets, "trial.css"), trialCss);
    std.file.write(buildPath(assets, "trial.js"), trialJs);
  }
}

version (unittest)
{
  import fluent.asserts;
}

@("it should set the result json")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new HtmlReporter("trial-result.html");

  auto begin = Clock.currTime - 10.seconds;
  auto end = begin + 10.seconds;

  auto testResult = new TestResult("some test");
  testResult.begin = begin;
  testResult.end = end;
  testResult.status = TestResult.Status.success;

  SuiteResult[] result = [SuiteResult("Test Suite", begin, end, [testResult])];
  reporter.end(result);

  auto text = readText("trial-result.html");

  text.should.contain(result[0].toString);
}
