/++
  A module containing the default test discovery logic

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.discovery.unit;

import std.stdio;
import std.string;
import std.traits;
import std.conv;
import std.array;
import std.file;
import std.algorithm;

import trial.interfaces;

/// The default test discovery looks for unit test sections and groups them by module
class UnitTestDiscovery : ITestDiscovery{
	TestCase[string][string] testCases;

	TestCase[] getTestCases() {
		return testCases.values.map!(a => a.values).joiner.array;
	}

	void addModule(string file, string moduleName)()
	{
		mixin("import " ~ moduleName ~ ";");
		mixin("discover!(`" ~ file ~ "`, `" ~ moduleName ~ "`, " ~ moduleName ~ ")();");
	}

	private {
		string testName(alias test)(ref string[] lines) {
			string defaultName = test.stringof.to!string;
			string name = defaultName;

			foreach (att; __traits(getAttributes, test)) {
				static if (is(typeof(att) == string)) {
					name = att;
				}
			}

			enum key = "__unittestL";
			enum len = key.length;

			if(name == defaultName && name.indexOf(key) == 0) {
				auto postFix = name[len..$];
				try {
					auto line = postFix[0..postFix.indexOf("_")].to!long;
					name = lines[line - 2];
				} catch(Exception e) {}
			}

			return name;
		}

		auto addTestCases(string file, alias moduleName, composite...)() if (composite.length == 1 && isUnitTestContainer!(composite))
		{	
			string[] lines = file.readText.split("\n");
			foreach (test; __traits(getUnitTests, composite)) {
				testCases[moduleName][test.mangleof] = TestCase(moduleName, testName!(test)(lines), {
					test();
				});
			}
		}

		void discover(string file, alias moduleName, composite...)() if (composite.length == 1 && isUnitTestContainer!(composite))
		{
			addTestCases!(file, moduleName, composite);

			static if (isUnitTestContainer!composite) {
				foreach (member; __traits(allMembers, composite)) {
					static if (
						__traits(compiles, __traits(getMember, composite, member)) &&
						isSingleField!(__traits(getMember, composite, member)) &&
						isUnitTestContainer!(__traits(getMember, composite, member)) &&
						!isModule!(__traits(getMember, composite, member))
						)
					{
						if (__traits(getMember, composite, member).mangleof !in testCases)
						{
							discover!(file, moduleName, __traits(getMember, composite, member))();
						}
					}
				}
			}
		}
	}
}

private template isUnitTestContainer(DECL...)
	if (DECL.length == 1)
{
	static if (!isAccessible!DECL) {
		enum isUnitTestContainer = false;
	} else static if (is(FunctionTypeOf!(DECL[0]))) {
		enum isUnitTestContainer = false;
	} else static if (is(DECL[0]) && !isAggregateType!(DECL[0])) {
		enum isUnitTestContainer = false;
	} else static if (isPackage!(DECL[0])) {
		enum isUnitTestContainer = false;
	} else static if (isModule!(DECL[0])) {
		enum isUnitTestContainer = DECL[0].stringof != "module object";
	} else static if (!__traits(compiles, fullyQualifiedName!(DECL[0]))) {
		enum isUnitTestContainer = false;
	} else static if (!is(typeof(__traits(allMembers, DECL[0])))) {
		enum isUnitTestContainer = false;
	} else {
		enum isUnitTestContainer = true;
	}
}

private template isModule(DECL...)
	if (DECL.length == 1)
{
	static if (is(DECL[0])) enum isModule = false;
	else static if (is(typeof(DECL[0])) && !is(typeof(DECL[0]) == void)) enum isModule = false;
	else static if (!is(typeof(DECL[0].stringof))) enum isModule = false;
	else static if (is(FunctionTypeOf!(DECL[0]))) enum isModule = false;
	else enum isModule = DECL[0].stringof.startsWith("module ");
}

private template isPackage(DECL...)
	if (DECL.length == 1)
{
	static if (is(DECL[0])) enum isPackage = false;
	else static if (is(typeof(DECL[0])) && !is(typeof(DECL[0]) == void)) enum isPackage = false;
	else static if (!is(typeof(DECL[0].stringof))) enum isPackage = false;
	else static if (is(FunctionTypeOf!(DECL[0]))) enum isPackage = false;
	else enum isPackage = DECL[0].stringof.startsWith("package ");
}

private template isAccessible(DECL...)
	if (DECL.length == 1)
{
	enum isAccessible = __traits(compiles, testTempl!(DECL[0])());
}

private template isSingleField(DECL...)
{
	enum isSingleField = DECL.length == 1;
}

private void testTempl(X...)()
	if (X.length == 1)
{
	static if (is(X[0])) {
		auto x = X[0].init;
	} else {
		auto x = X[0].stringof;
	}
}

version(unittest) {
	import fluent.asserts;
}

/// It should find this test
unittest
{
	auto testDiscovery = new UnitTestDiscovery;

	testDiscovery.addModule!(__FILE__, "trial.discovery.unit");

	testDiscovery.testCases.keys.should.contain("trial.discovery.unit");
	testDiscovery.testCases["trial.discovery.unit"].keys.length.should.equal(1);
	
	auto key = testDiscovery.testCases["trial.discovery.unit"].keys[0];
	testDiscovery.testCases["trial.discovery.unit"][key].name.should.equal("It should find this test");
}
