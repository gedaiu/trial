/++
  A module containing the reporter used when the tests are run by an AI harness.
  It prints plain text, only for the failed tests, followed by one summary line.

  Copyright: © 2026 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.agent;

import std.algorithm;
import std.array;
import std.conv;
import std.string;

import trial.interfaces;
import trial.reporters.writer;

version (unittest) {
  version (Have_fluent_asserts) {
    import fluent.asserts;
  }
}

/// The environment variables set by the known AI harnesses
immutable agentVariables = [
  "AI_AGENT", "CLAUDECODE", "CURSOR_AGENT", "CODEX_SANDBOX", "GEMINI_CLI", "OPENCODE", "CLINE_ACTIVE"
];

/// Checks if the tests are run by an AI harness. `TRIAL_AGENT` overrides the detection.
bool isAgentHarness(const string[string] environment) {
  if (auto forced = "TRIAL_AGENT" in environment) {
    return *forced != "0";
  }

  return agentVariables.any!(a => (a in environment) !is null);
}

/// isAgentHarness returns true when CLAUDECODE is set
unittest {
  ["CLAUDECODE": "1"].isAgentHarness.should.equal(true);
}

/// isAgentHarness returns false when only PATH is set
unittest {
  ["PATH": "/usr/bin"].isAgentHarness.should.equal(false);
}

/// isAgentHarness returns false when CLAUDECODE is set and TRIAL_AGENT is "0"
unittest {
  ["CLAUDECODE": "1", "TRIAL_AGENT": "0"].isAgentHarness.should.equal(false);
}

/// isAgentHarness returns true when only TRIAL_AGENT is "1"
unittest {
  ["TRIAL_AGENT": "1"].isAgentHarness.should.equal(true);
}

/// Describes where and why a test failed, one indented line per message line
string[] toAgentLines(Throwable throwable) {
  if (throwable is null) {
    return [];
  }

  return ["  at: " ~ throwable.file ~ ":" ~ throwable.line.to!string] ~
    throwable.msg.strip.splitLines.map!(a => "  " ~ a).array;
}

/// toAgentLines returns no lines when the throwable is null
unittest {
  toAgentLines(null).should.equal([]);
}

/// toAgentLines returns the location followed by the 2 indented message lines
unittest {
  auto lines = new Exception("Expected: 404\nActual: 200\n", "api.d", 42).toAgentLines;

  lines.should.equal(["  at: api.d:42", "  Expected: 404", "  Actual: 200"]);
}

/// Describes a failed test with its location, its failure and the filter that runs it again
string toAgentFailure(string suite, TestResult test) {
  auto fullName = suite ~ " " ~ test.name;

  auto lines = ["FAIL " ~ fullName, "  test: " ~ test.fileName ~ ":" ~ test.line.to!string] ~
    test.throwable.toAgentLines ~
    (`  rerun: -f "=` ~ fullName.replace(`"`, `\"`) ~ `"`);

  return lines.join("\n");
}

/// toAgentFailure returns the name, both locations, the message and an exact "=" rerun filter
unittest {
  auto test = new TestResult(`returns "404"`);
  test.fileName = "tests/api.d";
  test.line = 30;
  test.throwable = new Exception("Expected: 404", "tests/api.d", 42);

  toAgentFailure("ogm.maps", test).should.equal(
    "FAIL ogm.maps returns \"404\"\n" ~
      "  test: tests/api.d:30\n" ~
      "  at: tests/api.d:42\n" ~
      "  Expected: 404\n" ~
      "  rerun: -f \"=ogm.maps returns \\\"404\\\"\"");
}

/// Counts the tests that ended with a status
size_t countTests(SuiteResult[] results, TestResult.Status status) {
  return results.map!(a => a.tests).joiner.count!(a => a.status == status);
}

/// countTests returns 2 when 2 of the 3 tests in 2 suites are successful
unittest {
  auto results = [SuiteResult("a"), SuiteResult("b")];
  results[0].tests = [new TestResult("1"), new TestResult("2")];
  results[1].tests = [new TestResult("3")];
  results[0].tests[0].status = TestResult.Status.success;
  results[1].tests[0].status = TestResult.Status.success;

  results.countTests(TestResult.Status.success).should.equal(2);
}

/// Describes the whole run on one line
string toAgentSummary(SuiteResult[] results) {
  return format!"RESULT failed=%s passed=%s pending=%s skipped=%s"(
    results.countTests(TestResult.Status.failure),
    results.countTests(TestResult.Status.success),
    results.countTests(TestResult.Status.pending),
    results.countTests(TestResult.Status.skip));
}

/// toAgentSummary returns failed=1 passed=1 when a suite has a failed and a successful test
unittest {
  auto results = [SuiteResult("a")];
  results[0].tests = [new TestResult("1"), new TestResult("2")];
  results[0].tests[0].status = TestResult.Status.failure;
  results[0].tests[1].status = TestResult.Status.success;

  results.toAgentSummary.should.equal("RESULT failed=1 passed=1 pending=0 skipped=0");
}

/// toAgentSummary returns only zeros when there are no results
unittest {
  toAgentSummary([]).should.equal("RESULT failed=0 passed=0 pending=0 skipped=0");
}

/// This reporter prints the failed tests and a summary as plain text, without colors or glyphs
class AgentReporter : ILifecycleListener, ITestCaseLifecycleListener {
  ///
  ReportWriter writer;

  ///
  this() {
    this(new ConsoleWriter);
  }

  ///
  this(ReportWriter writer) {
    this.writer = writer;
  }

  ///
  void begin(ulong) {
  }

  ///
  void update() {
  }

  ///
  void end(SuiteResult[] results) {
    writer.writeln(results.toAgentSummary, ReportWriter.Context._default);
  }

  ///
  void begin(string, ref TestResult) {
  }

  ///
  void end(string suite, ref TestResult test) {
    if (test.status != TestResult.Status.failure) {
      return;
    }

    writer.writeln(toAgentFailure(suite, test) ~ "\n", ReportWriter.Context._default);
  }
}

/// AgentReporter prints nothing when a test is successful
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new AgentReporter(writer);

  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  reporter.end("some suite", test);

  writer.buffer.should.equal("");
}

/// AgentReporter prints the failure followed by an empty line when a test fails
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new AgentReporter(writer);

  auto test = new TestResult("some test");
  test.fileName = "file.d";
  test.line = 10;
  test.status = TestResult.Status.failure;

  reporter.end("some suite", test);

  writer.buffer.should.equal("FAIL some suite some test\n" ~
      "  test: file.d:10\n" ~
      "  rerun: -f \"=some suite some test\"\n\n");
}

/// AgentReporter prints the summary when the run ends
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new AgentReporter(writer);

  reporter.end([]);

  writer.buffer.should.equal("RESULT failed=0 passed=0 pending=0 skipped=0\n");
}
