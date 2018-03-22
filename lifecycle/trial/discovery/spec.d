/++
  A module containing the discovery logic for spec tests

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.discovery.spec;

import std.algorithm;
import std.stdio;
import std.array;
import std.traits;
import std.string;

import trial.interfaces;
import trial.discovery.code;

version (Have_fluent_asserts) {
  version = Have_fluent_asserts_core;
}

alias SetupFunction = void delegate() @system;

private string[] suitePath;
private ulong[string] testsPerSuite;
private TestCase[] testCases;
private SetupFunction[] beforeList;
private SetupFunction[] afterList;

/// Define a Spec test suite
void describe(T)(string name, T description)
{
  if (suitePath.length == 0)
  {
    suitePath = [moduleName!description];
  }

  auto beforeListIndex = beforeList.length;
  auto afterListIndex = afterList.length;

  suitePath ~= name;

  description();

  beforeList = beforeList[0 .. beforeListIndex];
  afterList = afterList[0 .. afterListIndex];

  suitePath = suitePath[0 .. $ - 1];
}

/// Define a function that will be ran before all the tests
void before(T)(T setup)
{
  bool wasRun;
  beforeList ~= {
    if (!wasRun)
    {
      setup();
      wasRun = true;
    }
  };
}

/// Define a function that will be ran before each test
void beforeEach(T)(T setup)
{
  beforeList ~= { setup(); };
}

/// Define a function that will be ran after each test
void afterEach(T)(T setup)
{
  afterList ~= { setup(); };
}

/// Define a function that will be ran after all the tests were ran
void after(T)(T setup)
{
  string suiteName = suitePath.join(".");
  long executedTests;
  bool wasRun;

  afterList ~= {
    if (wasRun)
    {
      return;
    }

    executedTests++;

    if (testsPerSuite[suiteName] < executedTests)
    {
      setup();
      wasRun = true;
    }
  };
}

private void updateTestCounter(string[] path, long value)
{
  string tmp;
  string glue;

  foreach (key; path)
  {
    tmp ~= glue ~ key;
    glue = ".";

    testsPerSuite[tmp] += value;
  }
}

/// Define a Spec
void it(T)(string name, T test, string file = __FILE__, size_t line = __LINE__)
{
  auto before = beforeList.dup;
  auto after = afterList.dup;
  auto path = suitePath.dup;

  reverse(after);

  updateTestCounter(path, 1);

  auto testCase = TestCase(suitePath.join("."), name, ({
      before.each!"a()";
      test();

      updateTestCounter(path, -1);
      after.each!"a()";
    }));

  testCase.location = SourceLocation(file, line);

  testCases ~= testCase;
}


/// Define a pending Spec
void it(string name, string file = __FILE__, size_t line = __LINE__)
{
  auto before = beforeList.dup;
  auto after = afterList.dup;
  auto path = suitePath.dup;

  reverse(after);

  updateTestCounter(path, 1);

  auto testCase = TestCase(suitePath.join("."), name, ({ throw new PendingTestException(); }));

  testCase.location = SourceLocation(file, line);

  testCases ~= testCase;
}

/// The main spec container
template Spec(alias definition)
{
  shared static this()
  {
    suitePath = [moduleName!definition];
    definition();
  }
}

/// The default test discovery looks for unit test sections and groups them by module
class SpecTestDiscovery : ITestDiscovery
{
  /// Returns all the Specs as TestCase structure
  TestCase[] getTestCases()
  {
    return testCases;
  }

  /// It does nothing...
  void addModule(string file, string moduleName)()
  {
  }

  private void noTest()
  {
    assert(false, "you can not run this test");
  }

  version (Have_libdparse)
  {
    private TestCase[] getTestCasesFromSpec(string file, string suite, const(Token)[] tokens) {
      TestCase[] testCases;
      auto iterator = TokenIterator(tokens);

      foreach(token; iterator) {
        if(token.text == "describe") {
          iterator.skipOne.skipWsAndComments;

          if(str(iterator.currentToken.type) == "(") {
            iterator.skipUntilType("stringLiteral");
            string suiteName = iterator.currentToken.text.parseString.strip;

            auto block = iterator.readNextBlock;
            testCases ~= getTestCasesFromSpec(file, suite ~ "." ~ suiteName, block);
          }
        }

        if(token.text == "it") {
          iterator.skipOne.skipWsAndComments;
          auto location = SourceLocation(file, iterator.currentToken.line);

          if(str(iterator.currentToken.type) == "(") {
            iterator.skipUntilType("stringLiteral");
            string testName = iterator.currentToken.text.parseString;

            testCases ~= TestCase(suite, testName, &this.noTest, [], location);
          }
        }
      }

      return testCases;
    }
  }

  TestCase[] discoverTestCases(string file)
  {
    TestCase[] testCases = [];

    version (Have_fluent_asserts_core)
      version (Have_libdparse)
      {
        import fluentasserts.core.results;

        auto tokens = fileToDTokens(file);

        auto iterator = TokenIterator(tokens);
        auto moduleName = iterator.skipUntilType("module").skipOne.readUntilType(";").strip;

        string lastName;
        DLangAttribute[] attributes;

        foreach (token; iterator)
        {
          auto type = str(token.type);

          if(token.text == "Spec") {
            iterator.skipOne.skipWsAndComments;

            if(str(iterator.currentToken.type) == "!") {
              iterator.skipOne.skipWsAndComments;

              if(str(iterator.currentToken.type) == "(") {
                auto block = iterator.readNextBlock;

                testCases ~= getTestCasesFromSpec(file, moduleName, block);
              }
            }
          }
         }
      }

    return testCases;
  }
}

///
string parseString(string someString) {
  if(someString == ""){
    return "";
  }

  if(someString[0] == '"') {
    return someString[1..$-1].replace(`\"`, `"`);
  }

  return someString[1..$-1];
}

/// resolve the string tokens
unittest
{
  `"string token"`.parseString.should.equal("string token");
  `"string \" token"`.parseString.should.equal("string \" token");
  "`string token`".parseString.should.equal("string token");
}

version (unittest)
{
  version(Have_fluent_asserts_core): 

  import fluent.asserts;

  private static string trace;

  private alias suite = Spec /* some comment*/ ! /* some comment*/ ( /* some comment*/ {
    describe("Algorithm", {
      it("should return false when the value is not present", {
        [1, 2, 3].canFind(4).should.equal(false);
      });
    });

    describe /* some comment*/ ("Nested describes", {
      describe("level 1", { describe("level 2", { it( /* some comment*/ "test name", {  }); }); });

      describe("other level 1", { describe("level 2", { it("test name", {  }); });  });
    });

    describe("Before all", {
      before({ trace ~= "before1"; });

      describe("level 2", {
        before({ trace ~= " before2"; });

        it("should run the hooks", { trace ~= " test1"; });

        it("should run the hooks", { trace ~= " test2"; });
      });

      describe("level 2 bis", {
        before({ trace ~= "before2-bis"; });

        it("should run the hooks", { trace ~= " test3"; });
      });
    });

    describe("Before each", {
      beforeEach({ trace ~= "before1 "; });

      it("should run the hooks", { trace ~= "test1 "; });

      describe("level 2", {
        beforeEach({ trace ~= "before2 "; });

        it("should run the hooks", { trace ~= "test2 "; });
      });

      describe("level 2 bis", {
        beforeEach({ trace ~= "before2-bis "; });

        it("should run the hooks", { trace ~= "test3"; });
      });
    });

    describe("After all", {
      after({ trace ~= "after1"; });

      describe("level 2", {
        after({ trace ~= " after2 "; });

        it("should run the hooks", { trace ~= "test1"; });

        it("should run the hooks", { trace ~= " test2"; });
      });

      describe("level 2 bis", {
        after({ trace ~= "after2-bis"; });

        it("should run the hooks", { trace ~= "test3 "; });
      });
    });

    describe("After each", {
      afterEach({ trace ~= " after1"; });

      it("should run the hooks", { trace ~= "test1"; });

      describe("level 2", {
        afterEach({ trace ~= " after2"; });

        it("should run the hooks", { trace ~= " test2"; });
      });

      describe("level 2 bis", {
        afterEach({ trace ~= " after2-bis"; });

        it("should run the hooks", { trace ~= "test3"; });
      });
    });
  });
}

/// getTestCases should find the spec suite
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto tests = specDiscovery.getTestCases.filter!(
      a => a.suiteName == "trial.discovery.spec.Algorithm").array;

  tests.length.should.equal(1).because("the Spec suite defined is in this file");
  tests[0].name.should.equal("should return false when the value is not present");
}

/// discoverTestCases should find the spec suite
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto tests = specDiscovery.discoverTestCases(__FILE__).filter!(
      a => a.suiteName == "trial.discovery.spec.Algorithm").array;

  tests.length.should.equal(1).because("the Spec suite defined is in this file");
  tests[0].name.should.equal("should return false when the value is not present");
}

/// getTestCases should find the spec suite
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto tests = specDiscovery.getTestCases.filter!(
      a => a.suiteName == "trial.discovery.spec.Algorithm").array;

  tests.length.should.equal(1).because("the Spec suite defined is in this file");
  tests[0].name.should.equal("should return false when the value is not present");
}

/// getTestCases should find nested spec suites
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto suites = specDiscovery.getTestCases.map!(a => a.suiteName).array;

  suites.should.contain(["trial.discovery.spec.Nested describes.level 1.level 2",
      "trial.discovery.spec.Nested describes.other level 1.level 2"]).because(
      "the Spec suites are defined in this file");
}

/// It should execute the spec before all hooks
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto tests = specDiscovery.getTestCases.filter!(
      a => a.suiteName.startsWith("trial.discovery.spec.Before all")).array;

  trace = "";
  tests[0].func();
  tests[1].func();

  trace.should.equal("before1 before2 test1 test2");

  trace = "";
  tests[2].func();

  trace.should.equal("before2-bis test3");
}

/// It should execute the spec after all hooks
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto tests = specDiscovery.getTestCases.filter!(
      a => a.suiteName.startsWith("trial.discovery.spec.After all")).array;

  trace = "";
  tests[0].func();
  tests[1].func();

  trace.should.equal("test1 test2 after2 after1");

  trace = "";
  tests[2].func();

  trace.should.equal("test3 after2-bis");
}

/// It should execute the spec before hooks
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto tests = specDiscovery.getTestCases.filter!(
      a => a.suiteName.startsWith("trial.discovery.spec.Before each")).array;

  trace = "";
  tests[0].func();
  tests[1].func();

  trace.should.equal("before1 test1 before1 before2 test2 ");

  trace = "";
  tests[2].func();

  trace.should.equal("before1 before2-bis test3");
}

/// It should execute the spec after hooks
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto tests = specDiscovery.getTestCases.filter!(
      a => a.suiteName.startsWith("trial.discovery.spec.After each")).array;

  trace = "";
  tests[0].func();
  tests[1].func();

  trace.should.equal("test1 after1 test2 after2 after1");

  trace = "";
  tests[2].func();

  trace.should.equal("test3 after2-bis after1");
}

/// discoverTestCases should find the same tests like testCases
unittest
{
  auto testDiscovery = new SpecTestDiscovery;

  testDiscovery
    .discoverTestCases(__FILE__).map!(a => a.toString).join("\n")
      .should.equal(
        testDiscovery.getTestCases
        .filter!(a => a.location.fileName.canFind(__FILE__))
        .map!(a => a.toString).join("\n"));
}
