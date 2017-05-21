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

class HtmlReporter : ILifecycleListener {

  string header = `<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Test Result</title></head><body>`;

  string footer = `</body></html>`;

  private {
    bool success = true;
  }

  void begin(ulong) {}

  void update() {}

  void end(SuiteResult[] results) {
    string content = header;

    string duration(T)(T item) {
      return ` <span class="duration">` ~ (item.end - item.begin).to!string ~ `</span> `;
    }

    foreach(result; results) {
      content ~= "<h1>" ~ result.name ~ "<small>"~ duration(result) ~ "</small></h1>\n";

      content ~= `<dl class="suiteResult">`;
      foreach(test; result.tests) {
        content ~= "<dt>" ~ test.name ~ duration(test) ~ "</dt><dd>" ~ test.status.to!string ~"</dd>\n";
      }
      content ~= `</dl>`;
    }

    content ~= footer;

    std.file.write("trial-result.html", content);
  }
}

version(unittest) {
  import fluent.asserts;
}

@("it should print a success test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new HtmlReporter();

  auto begin = Clock.currTime - 10.seconds;
  auto end = begin + 10.seconds;

  auto testResult = new TestResult("some test");
  testResult.begin = begin;
  testResult.end = end;
  testResult.status = TestResult.Status.success;

  SuiteResult[] result = [ SuiteResult("Test Suite", begin, end, [ testResult ]) ];
  reporter.end(result);

  auto text = readText("trial-result.html");

  text.should.contain(`<h1>Test Suite<small> <span class="duration">10 secs</span> </small></h1>`);
  text.should.contain(`<dt>some test <span class="duration">10 secs</span> </dt><dd>success</dd>`);
}
