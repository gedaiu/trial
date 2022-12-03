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
    bool success = true;
    immutable string destination;
    immutable long warningTestDuration;
    immutable long dangerTestDuration;
  }

  this(string destination, long warningTestDuration, long dangerTestDuration)
  {
    this.destination = destination;
    this.warningTestDuration = warningTestDuration;
    this.dangerTestDuration = dangerTestDuration;
  }

  void begin(ulong)
  {
  }

  void update()
  {
  }

  private {
    void relativePaths(ref SuiteResult[] results) {
      foreach(ref result; results) {
        relativePaths(result);
      }
    }

    void relativePaths(ref SuiteResult suite) {
      relativePaths(suite.attachments);
      
      foreach(ref result; suite.tests) {
        relativePaths(result);
      }
    }

    void relativePaths(ref TestResult step) {
      relativePaths(step.attachments);

      foreach(ref child; step.steps) {
        relativePaths(child);
      }
    }

    void relativePaths(ref StepResult step) {
      relativePaths(step.attachments);

      foreach(ref child; step.steps) {
        relativePaths(child);
      }
    }

    void relativePaths(ref Attachment[] attachments) {
      foreach(ref attachment; attachments) {
        attachment.file = asRelativePath(attachment.file, destination.dirName).array;
      }
    }
  }

  void end(SuiteResult[] results)
  {
    relativePaths(results);

    immutable string trialCss = import("assets/trial.css");
    immutable string trialJs = import("assets/trial.js");

    string content = import("templates/htmlReporter.html");

    auto assets = buildPath(destination.dirName, "assets");

    if(!destination.dirName.exists) {
      mkdirRecurse(destination.dirName);
    }

    if(!assets.exists) {
      mkdirRecurse(assets);
    }

    content = content
      .replace("{testResult}", "[" ~ results.map!(a => a.toString).join(",") ~ "]")
      .replace("{warningTestDuration}", warningTestDuration.to!string)
      .replace("{dangerTestDuration}", dangerTestDuration.to!string);


    std.file.write(destination, content);

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
  auto reporter = new HtmlReporter("trial-result.html", 0, 0);

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
