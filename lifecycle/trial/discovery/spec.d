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

import trial.interfaces;

alias SetupFunction = void delegate() nothrow @safe;

private string[] suitePath;
private TestCase[] testCases;
private SetupFunction[] beforeList;

void describe(T)(string name, T description)
{
  if(suitePath.length == 0) {
    suitePath = [ moduleName!description ];
  }

  suitePath ~= name;

  import std.stdio;
  1.writeln("!!!", name);

  description();

  suitePath = suitePath[0 .. $-1];
}

void before(T)(T setup) {
  pragma(msg, "==> ? ", T);

  bool wasRun;
  beforeList ~= {
    if(!wasRun) {
      setup();
      wasRun = true;
    }
  };
}

void it(T)(string name, T test)
{
  auto before = beforeList.dup;

  testCases ~= TestCase(suitePath.join("."), name, ({
    before.each!"a()";
    test();
  }));
}

template Spec(alias definition)
{
  shared static this() {
    definition();
  }
}

/// The default test discovery looks for unit test sections and groups them by module
class SpecTestDiscovery : ITestDiscovery
{
  TestCase[] getTestCases() {
    return testCases;
  }
}

version (unittest)
{

  import fluent.asserts;

  private static string trace;

  private alias suite = Spec!({
    describe("Algorithm", {
      it("should return false when the value is not present", {
        [1, 2, 3].canFind(4).should.equal(false);
      });
    });

    describe("Nested describes", {
      describe("level 1", {
        describe("level 2", {
          it("test name", { });
        });
      });

      describe("other level 1", {
        describe("level 2", {
          it("test name", { });
        });
      });
    });

    describe("Before all", {
      before({
        trace ~= "before1";
      });

      describe("level 2", {
        before({
          trace ~= " before2";
        });

        it("should run the hooks", {
          trace ~= " test";
        });
      });

      describe("level 2 bis", {
        before({
          trace ~= "before2-bis";
        });

        it("should run the hooks", {
          trace ~= " test2";
        });
      });
    });
  });

}

/// It should find the spec suite
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto tests = specDiscovery.getTestCases.filter!(a => a.suiteName == "trial.discovery.spec.Algorithm").array;

  tests.length.should.equal(1).because("the Spec suite defined is in this file");
  tests[0].name.should.equal("should return false when the value is not present");
}

/// It should find nested spec suites
unittest
{
  auto specDiscovery = new SpecTestDiscovery;
  auto suites = specDiscovery.getTestCases.map!(a => a.suiteName).array;

  suites.should.contain([
    "trial.discovery.spec.Nested describes.level 1.level 2",
    "trial.discovery.spec.Nested describes.other level 1.level 2" ])
    .because("the Spec suites are defined in this file");
}

/// It should execute the spec before all hooks
unittest {
  auto specDiscovery = new SpecTestDiscovery;
  auto tests = specDiscovery.getTestCases.filter!(a => a.suiteName.startsWith("trial.discovery.spec.Before all")).array;

  trace = "";
  tests[0].func();

  trace.should.equal("before1 before2 test");

  trace = "";
  tests[1].func();

  trace.should.equal("before2-bis test2");
}
