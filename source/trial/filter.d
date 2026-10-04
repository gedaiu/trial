/++
  A module containing the logic used to select tests by name

  Copyright: © 2026 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.filter;

import trial.interfaces : SourceLocation, TestCase;
import trial.arguments : RunArguments;

version (unittest) {
  version (Have_fluent_asserts) {
    import fluent.asserts;
  }

  /// A test body that does nothing
  void TestMock() @system {
  }

  /// The "suite name" names of the tests, in order
  string[] fullNames(const(TestCase)[] tests) {
    import std.algorithm : map;
    import std.array : array;

    return tests.map!(a => a.suiteName ~ " " ~ a.name).array;
  }
}

/// Checks if a test name is selected by the given filter
bool matchesFilter(string text, string filter) {
  import std.algorithm : canFind, endsWith, startsWith;
  import std.regex : matchFirst, regex;

  if (filter.length >= 2 && filter.startsWith("/") && filter.endsWith("/")) {
    return !matchFirst(text, regex(filter[1 .. $ - 1])).empty;
  }

  if (filter.startsWith("=")) {
    return text == filter[1 .. $];
  }

  return filter.length == 0 || text.canFind(filter);
}

/// matchesFilter returns true for "some test" and an empty filter
unittest {
  matchesFilter("some test", "").should.equal(true);
}

/// matchesFilter returns true for an empty text and an empty filter
unittest {
  matchesFilter("", "").should.equal(true);
}

/// matchesFilter returns false for "some test" and the filter "other"
unittest {
  matchesFilter("some test", "other").should.equal(false);
}

/// matchesFilter returns true for "some test" and the exact filter "=some test"
unittest {
  matchesFilter("some test", "=some test").should.equal(true);
}

/// matchesFilter returns true for "some test" and the regex filter for "some test" or "some case"
unittest {
  matchesFilter("some test", "/^some (test|case)$/").should.equal(true);
}

/// Selects the tests matching the run arguments
const(TestCase)[] selectTests(const(TestCase)[] tests, RunArguments arguments) {
  import std.algorithm : filter;
  import std.array : array;

  auto named = tests.filter!(a => matchesFilter(a.suiteName, arguments.suiteName)
    && matchesFilter(a.name, arguments.testName)
    && matchesFilter(a.suiteName ~ " " ~ a.name, arguments.fullName)).array;

  return selectAt(named, arguments.at);
}

/// selectTests returns both tests "a.b first" and "a.c second" for empty arguments
unittest {
  const(TestCase)[] tests = [
    TestCase("a.b", "first", &TestMock),
    TestCase("a.c", "second", &TestMock)
  ];

  selectTests(tests, RunArguments()).fullNames.should.equal(["a.b first", "a.c second"]);
}

/// selectTests returns only "a.b some test" for the test name filter "=some test"
unittest {
  const(TestCase)[] tests = [
    TestCase("a.b", "some test", &TestMock),
    TestCase("a.b", "some test extra", &TestMock),
    TestCase("a.c", "other", &TestMock)
  ];

  RunArguments arguments;
  arguments.testName = "=some test";

  selectTests(tests, arguments).fullNames.should.equal(["a.b some test"]);
}

/// selectTests returns only "a.c some test" for the suite filter "=a.c" and the test name filter "some"
unittest {
  const(TestCase)[] tests = [
    TestCase("a.b", "some test", &TestMock),
    TestCase("a.c", "some test", &TestMock),
    TestCase("a.cd", "other", &TestMock)
  ];

  RunArguments arguments;
  arguments.suiteName = "=a.c";
  arguments.testName = "some";

  selectTests(tests, arguments).fullNames.should.equal(["a.c some test"]);
}

/// selectTests returns only "a.b some test" for the full name filter "=a.b some test"
unittest {
  const(TestCase)[] tests = [
    TestCase("a.b", "some test", &TestMock),
    TestCase("a.b", "some test extra", &TestMock),
    TestCase("a.c", "some test", &TestMock)
  ];

  RunArguments arguments;
  arguments.fullName = "=a.b some test";

  selectTests(tests, arguments).fullNames.should.equal(["a.b some test"]);
}

/// selectTests returns only "a.b first" for the location at line 15 of a file with tests at lines 10 and 20
unittest {
  auto first = TestCase("a.b", "first", &TestMock);
  first.location = SourceLocation("source/a/b.d", 10);

  auto second = TestCase("a.b", "second", &TestMock);
  second.location = SourceLocation("source/a/b.d", 20);

  const(TestCase)[] tests = [first, second];

  RunArguments arguments;
  arguments.at = "a/b.d:15";

  selectTests(tests, arguments).fullNames.should.equal(["a.b first"]);
}

/// Parses a `--at` value shaped like `file.d:42`
SourceLocation parseLocation(string at) {
  import std.algorithm : all;
  import std.ascii : isDigit;
  import std.conv : to;
  import std.exception : enforce;
  import std.string : lastIndexOf;

  auto separator = at.lastIndexOf(':');
  enforce(separator > 0 && at.length > separator + 1 && at[separator + 1 .. $].all!isDigit,
    "The `--at` value `" ~ at ~ "` must look like file.d:42");

  return SourceLocation(at[0 .. separator], at[separator + 1 .. $].to!size_t);
}

/// parseLocation returns the file "a/b.d" and the line 15 for "a/b.d:15"
unittest {
  parseLocation("a/b.d:15").should.equal(SourceLocation("a/b.d", 15));
}

/// parseLocation throws for "a/b.d" without a line number
unittest {
  ({ parseLocation("a/b.d"); }).should.throwException!Exception.withMessage("The `--at` value `a/b.d` must look like file.d:42");
}

/// Selects the tests enclosing the `file:line` location, or all tests when it is empty
const(TestCase)[] selectAt(const(TestCase)[] tests, string at) {
  import std.algorithm : endsWith, filter, map, maxElement;
  import std.array : array;

  if (at.length == 0) {
    return tests;
  }

  auto target = parseLocation(at);

  auto candidates = tests.filter!(a => a.location.fileName.endsWith(target.fileName)
    && a.location.line <= target.line).array;

  if (candidates.length == 0) {
    return candidates;
  }

  auto enclosingLine = candidates.map!(a => a.location.line).maxElement;

  return candidates.filter!(a => a.location.line == enclosingLine).array;
}
