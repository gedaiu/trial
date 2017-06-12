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

import trial.interfaces;
import trial.reporters.writer;

/// The "html" reporter outputs a hierarchical HTML body representation of your tests.
class HtmlReporter : ILifecycleListener
{
  string header = `<!DOCTYPE html>
  <html>
  <head>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
    <meta charset="UTF-8">
    <title>Test Result</title>
  </head>
  <body>`;

  string footer = `</body></html>`;

  private
  {
    bool success = true;
  }

  void begin(ulong)
  {
  }

  void update()
  {
  }

  void end(SuiteResult[] results)
  {
    string content = header;

    string escapeHtml(string text)
    {
      return text.replace("<", "&lt;").replace(">", "&gt;");
    }

    string duration(T)(T item) pure
    {
      return ` <span class="duration">` ~ (item.end - item.begin).to!string ~ `</span> `;
    }

    string testStatus(T)(T item)
    {
      if (item.status == TestResult.Status.success)
      {
        return `<span class="label label-success">` ~ item.status.to!string ~ `</span>`;
      }

      if (item.status == TestResult.Status.failure)
      {
        return `<span class="label label-danger">` ~ item.status.to!string ~ `</span>`;
      }

      return `<span class="label label-info">` ~ item.status.to!string ~ `</span>`;
    }

    content ~= `<div class="container-fluid">`;

    string details;
    double passes = 0;
    double failures = 0;
    double other = 0;
    Duration totalDuration = Duration.zero;

    foreach (result; results)
    {
      details ~= "\n<h1>" ~ escapeHtml(result.name) ~ "<small>" ~ duration(
          result) ~ "</small></h1>\n";
      totalDuration += result.end - result.begin;

      foreach (test; result.tests)
      {
        details ~= `<div class="row">`;
        details ~= `<div class="col-sm-4"><strong class='test-name'>` ~ escapeHtml(
            test.name) ~ `</strong></div>`;
        details ~= `<div class="col-sm-8">` ~ testStatus(
            test) ~ ` <span class="label label-default">` ~ duration(test) ~ `</span></div>`;
        details ~= `</div>`;

        if (test.throwable !is null)
        {
          details ~= `<pre>` ~ escapeHtml(test.throwable.to!string) ~ `</pre>`;
        }

        if (test.status == TestResult.Status.success)
        {
          passes++;
        }
        else if (test.status == TestResult.Status.failure)
        {
          failures++;
        }
        else
        {
          other++;
        }
      }
    }

    content ~= `<p>passes: <strong>` ~ passes.to!string ~ `</strong></p>`;
    content ~= `<p>failures: <strong>` ~ failures.to!string ~ `</strong></p>`;
    content ~= `<p>other: <strong>` ~ other.to!string ~ `</strong></p>`;
    content ~= `<p>duration: <strong>` ~ totalDuration.to!string ~ `</strong></p>`;

    auto passPercent = ((passes / (passes + failures + other)) * 100);
    auto failurePercent = ((failures / (passes + failures + other)) * 100);
    auto otherPercent = ((other / (passes + failures + other)) * 100);

    content ~= `<div class="progress">
      <div class="progress-bar progress-bar-success" style="width: ` ~ passPercent.to!string
      ~ `%;"></div>
      <div class="progress-bar progress-bar-danger" style="width: `
      ~ failurePercent.to!string ~ `%;"></div>
      <div class="progress-bar" style="width: `
      ~ otherPercent.to!string ~ `%;"></div>
    </div>`;

    content ~= details ~ "\n</div>" ~ footer;

    std.file.write("trial-result.html", content);
  }
}

version (unittest)
{
  import fluent.asserts;
}

@("it should print a success test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new HtmlReporter();

  auto begin = Clock.currTime - 10.seconds;
  auto end = begin + 10.seconds;

  auto testResult = new TestResult("some test");
  testResult.begin = begin;
  testResult.end = end;
  testResult.status = TestResult.Status.success;

  SuiteResult[] result = [ SuiteResult("Test Suite", begin, end, [testResult]) ];
  reporter.end(result);

  auto text = readText("trial-result.html");

  text.should.contain(`<h1>Test Suite<small> <span class="duration">10 secs</span> </small></h1>`);
  text.should.contain(`<strong class='test-name'>some test</strong>`);
  text.should.contain(`<span class="label label-success">success</span> <span class="label label-default"> <span class="duration">10 secs</span>`);

  text.should.contain(`passes: <strong>1</strong>`);
  text.should.contain(`failures: <strong>0</strong>`);
  text.should.contain(`other: <strong>0</strong>`);
  text.should.contain(`duration: <strong>10 secs</strong>`);
}

@("it should print a failure test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new HtmlReporter();

  auto begin = Clock.currTime - 10.seconds;
  auto end = begin + 10.seconds;

  auto testResult = new TestResult("some test");
  testResult.begin = begin;
  testResult.end = end;
  testResult.status = TestResult.Status.failure;
  testResult.throwable = new Exception("Some error");

  SuiteResult[] result = [SuiteResult("Test Suite", begin, end, [testResult])];
  reporter.end(result);

  auto text = readText("trial-result.html");

  text.should.contain(`<span class="label label-danger">failure</span>`);
  text.should.contain(`<pre>` ~ testResult.throwable.to!string ~ `</pre>`);
  text.should.contain(`passes: <strong>0</strong>`);
  text.should.contain(`failures: <strong>1</strong>`);
  text.should.contain(`other: <strong>0</strong>`);
  text.should.contain(`duration: <strong>10 secs</strong>`);
}
