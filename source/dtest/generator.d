module dtest.generator;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;

string generateTestFile(string[] modules) {
    enum d = import("discovery.d") ~ import("runner.d");

    auto code = d.split("\n")
                  .filter!(a => !a.startsWith("module"))
                  .filter!(a => a.indexOf("import") == -1 || a.indexOf("dtest.") == -1)
                  .join("\n");

    code ~= `
    void main() {
        TestDiscovery testDiscovery;`;

    foreach(m; modules) {
      code ~= `testDiscovery.addModule!"` ~ m ~ `";`;
    }

    code ~= `
        writeln("Found ", testDiscovery.testCases.length, " test cases");

        runTests(testDiscovery);
    }

    version (unittest) shared static this()
    {
        import core.runtime;
        Runtime.moduleUnitTester = () => true;
    }`;

    return code;
}


@("It should find this test")
unittest
{
  import dtest.discovery;

	TestDiscovery testDiscovery;

	testDiscovery.addModule!("dtest.discovery");
}
