/++
  A module containing the ListReporter

  This is an example of how this reporter looks
  <script type="text/javascript" src="https://asciinema.org/a/b4u0o9vba18dquzdgwif7anl5.js" id="asciicast-b4u0o9vba18dquzdgwif7anl5" async></script>

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.list;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;

import trial.interfaces;
import trial.reporters.spec;
import trial.reporters.writer;

/// The list reporter outputs a simple specifications list as test cases pass or 
/// fail
class ListReporter : SpecReporter
{
  this()
  {
    super();
  }

  this(ReportWriter writer)
  {
    super(writer);
  }

  override
  {
    void begin(string suite, ref TestResult)
    {

    }

    void end(string suite, ref TestResult test)
    {
      if(test.status == TestResult.Status.success) {
        write!(Type.success)("", 1);
        write!(Type.none)(suite ~ " " ~ test.name ~ "\n");
      } else {
        write!(Type.failure)(suite ~ " " ~ test.name ~ "\n", 1);
        failedTests++;
      }
    }
  }
}

version (unittest)
{
  import fluent.asserts;
}

@("it should print a sucess test")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new ListReporter(writer);

  auto test = new TestResult("other test");
  test.status = TestResult.Status.success;

  reporter.end("some suite", test);

  writer.buffer.should.equal("  ✓ some suite other test\n");
}

@("it should print two failing tests")
unittest
{
  auto writer = new BufferedWriter;
  auto reporter = new ListReporter(writer);

  auto test = new TestResult("other test");
  test.status = TestResult.Status.failure;

  reporter.end("some suite", test);
  reporter.end("some suite", test);

  writer.buffer.should.equal("  0) some suite other test\n  1) some suite other test\n");
}
