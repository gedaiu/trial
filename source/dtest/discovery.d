module dtest.discovery;

import std.stdio;
import std.string;
import std.traits;

alias testCaseFunction = void function() @system;

struct TestCase {
	string name;
	testCaseFunction func;
}

struct TestDiscovery {
	TestCase[string][string] testCases;

	void addModule(string name)()
	{
		mixin("import " ~ name ~ ";");
		mixin("discover!(`" ~ name ~ "`, " ~ name ~ ")();");
	}

	private {
		string testName(alias test)() {
			string name = "unknown";

			foreach (att; __traits(getAttributes, test)) {
				static if (is(typeof(att) == string)) {
					name = att;
				}
			}

			return name;
		}

		auto addTestCases(alias moduleName, composite...)() if (composite.length == 1 && isUnitTestContainer!(composite))
		{
			foreach (test; __traits(getUnitTests, composite)) {
				testCases[moduleName][test.mangleof] = TestCase(testName!test, {
					test();
				});
			}
		}

		void discover(alias moduleName, composite...)() if (composite.length == 1 && isUnitTestContainer!(composite))
		{
			addTestCases!(moduleName, composite);

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
							discover!(moduleName, __traits(getMember, composite, member))();
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
