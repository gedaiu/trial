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
import std.range;
import std.typecons;

import trial.interfaces;
import trial.discovery.code;

enum CommentType {
	none,
	begin,
	end,
	comment
}

CommentType commentType(T)(T line) {
	if(line.length < 2) {
		return CommentType.none;
	}

	if(line[0..2] == "//") {
		return CommentType.comment;
	}

	if(line[0..2] == "/+" || line[0..2] == "/*") {
		return CommentType.begin;
	}

	if(line.indexOf("+/") != -1 || line.indexOf("*/") != -1) {
		return CommentType.end;
	}

	return CommentType.none;
}

@("It should group comments")
unittest {
	string comments = "//line 1
	// line 2

	//// other line

	/** line 3
	line 4 ****/

	//// other line

	/++ line 5
	line 6
	+++/

	/** line 7
   *
   * line 8
   */";

	auto results = comments.compressComments;

	results.length.should.equal(6);
	results[0].value.should.equal("line 1 line 2");
	results[1].value.should.equal("other line");
	results[2].value.should.equal("line 3 line 4");
	results[3].value.should.equal("other line");
	results[4].value.should.equal("line 5 line 6");
	results[5].value.should.equal("line 7  line 8");

	results[0].line.should.equal(2);
	results[1].line.should.equal(4);
	results[2].line.should.equal(7);
	results[3].line.should.equal(9);
	results[4].line.should.equal(13);
}

struct Comment {
	ulong line;
	string value;
}

Comment[] commentGroupToString(T)(T[] group) {
	if(group.front[1] == CommentType.comment) {
		auto slice = group.until!(a => a[1] != CommentType.comment).array;

		string value = slice
			.map!(a => a[2].stripLeft('/').array.to!string)
			.map!(a => a.strip)
			.join(' ')
			.array.to!string;

		return [ Comment(slice[slice.length - 1][0], value) ];
	}

	if(group.front[1] == CommentType.begin) {
		auto ch = group.front[2][1];
		auto index = 0;

		auto newGroup = group
		.map!(a => Tuple!(int, CommentType, immutable(char), string)(a[0], a[1], a[2].length > 2 ? a[2][1] : ' ', a[2])).array;

		foreach(item; newGroup) {
			index++;
			if(item[1] == CommentType.end && item[2] == ch) {
				break;
			}
		}

		auto slice = group
			.map!(a => Tuple!(int, CommentType, immutable(char), string)(a[0], a[1], a[2].length > 2 ? a[2][1] : ' ', a[2]))
			.take(index);

		string value = slice
			.map!(a => a[3].strip)
			.map!(a => a.stripLeft('/').stripLeft(ch).array.to!string)
			.map!(a => a.strip)
			.join(' ')
			.until(ch ~ "/")
			.array
			.stripRight('/')
			.stripRight(ch)
			.strip
			.to!string;

		return [ Comment(slice[slice.length - 1][0], value) ];
	}

	return [];
}

string getComment(const Comment[] comments, const ulong line, const string defaultValue) pure {
	auto r = comments.filter!(a => (line - a.line) < 3);

	return r.empty ? defaultValue : r.front.value;
}

bool connects(T)(T a, T b) {
	auto items = a[0] < b[0] ? [a, b] : [b, a];

	if(items[1][0] - items[0][0] != 1) {
		return false;
	}

	if(a[1] == b[1]) {
		return true;
	}

	if(items[0][1] != CommentType.end && items[1][1] != CommentType.begin) {
		return true;
	}

	return false;
}

@("check comment types")
unittest
{
	"".commentType.should.equal(CommentType.none);
	"some".commentType.should.equal(CommentType.none);
	"//some".commentType.should.equal(CommentType.comment);
	"/+some".commentType.should.equal(CommentType.begin);
	"/*some".commentType.should.equal(CommentType.begin);
	"some+/some".commentType.should.equal(CommentType.end);
	"some*/some".commentType.should.equal(CommentType.end);
}

auto compressComments(string code)
{
	Comment[] result;

	auto lines = code
		.splitter("\n")
		.map!(a => a.strip)
		.enumerate(1)
		.map!(a => Tuple!(int, CommentType, string)(a[0], a[1].commentType, a[1]))
		.filter!(a => a[2] != "")
			.array;

	auto tmp = [ lines[0] ];
	auto prev = lines[0];

	foreach(line; lines[1..$]) {
		if(tmp.length == 0 || line.connects(tmp[tmp.length - 1])) {
			tmp ~= line;
		} else {
			result ~= tmp.commentGroupToString;
			tmp = [ line ];
		}
	}

	if(tmp.length > 0) {
		result ~= tmp.commentGroupToString;
	}

	return result;
}

/// Remove comment tokens
string clearCommentTokens(string text) {
	return text.strip('/').strip('+').strip('*').strip;
}

/// clearCommentTokens should remove comment tokens
unittest {
	clearCommentTokens("// text").should.equal("text");
	clearCommentTokens("///// text").should.equal("text");
	clearCommentTokens("/+++ text").should.equal("text");
	clearCommentTokens("/*** text").should.equal("text");
	clearCommentTokens("/*** text ***/").should.equal("text");
	clearCommentTokens("/+++ text +++/").should.equal("text");
}

/// The default test discovery looks for unit test sections and groups them by module
class UnitTestDiscovery : ITestDiscovery {
	TestCase[string][string] testCases;

	TestCase[] getTestCases() {
		return testCases.values.map!(a => a.values).joiner.array;
	}

	TestCase[] discoverTestCases(string file) {
		TestCase[] testCases = [];

		version(Have_fluent_asserts_core) version(Have_libdparse) {
			import fluentasserts.core.results;

			auto tokens = fileToDTokens(file);

			void noTest() {
				assert(false, "you can not run this test");
			}

			auto iterator = TokenIterator(tokens);

			auto moduleName = iterator.skipUntilType("module").skipOne.readUntilType(";").strip;

			string lastName;
			DLangAttribute[] attributes;

			foreach(token; iterator) {
				auto type = str(token.type);

				if(type == "}") {
					lastName = "";
					attributes = [];
				}

				if(type == "@") {
					attributes ~= iterator.readAttribute;
				}

				if(type == "comment") {
					if(lastName != "") {
						lastName ~= " ";
					}

					lastName ~= token.text.clearCommentTokens;
				}

				if(type == "version") {
					iterator.skipUntilType(")");
				}

				if(type == "unittest") {
					auto issues = attributes.filter!(a => a.identifier == "Issue");
					auto flakynes = attributes.filter!(a => a.identifier == "Flaky");
					auto stringAttributes = attributes.filter!(a => a.identifier == "");

					Label[] labels = [];

					foreach(issue; issues) {
						labels ~= Label("issue", issue.value);
					}

					if(!flakynes.empty) {
						labels ~= Label("flaky", "");
					}

					if(!stringAttributes.empty) {
						lastName = stringAttributes.front.value.strip;
					}

					if(lastName == "") {
						lastName = "__unittestL" ~ token.line.to!string;
					}

					auto testCase = TestCase(moduleName, lastName, &noTest, labels);
					testCase.location = SourceLocation(file, token.line);

					testCases ~= testCase;
				}
			}
		}

		return testCases;
	}

	void addModule(string file, string moduleName)()
	{
		mixin("import " ~ moduleName ~ ";");
		mixin("discover!(`" ~ file ~ "`, `" ~ moduleName ~ "`, " ~ moduleName ~ ")();");
	}

	private {
		string testName(alias test)(ref Comment[] comments) {
			string defaultName = test.stringof.to!string;
			string name = defaultName;

			foreach (attr; __traits(getAttributes, test)) {
				static if (is(typeof(attr) == string)) {
					name = attr;
				}
			}

			enum key = "__un" ~ "ittestL";
			enum len = key.length;

			if(name == defaultName && name.indexOf(key) == 0) {
				try {
					auto postFix = name[len..$];
					auto idx = postFix.indexOf("_");
					if(idx != -1) {
						auto line = postFix[0..idx].to!long;
						name = comments.getComment(line, defaultName);
					}
				} catch(Exception e) { }
			}

			return name;
		}

		SourceLocation testSourceLocation(alias test)(string fileName) {
			string name = test.stringof.to!string;

			enum key = "__un" ~ "ittestL";
			enum len = key.length;
			size_t line;

			try {
				auto postFix = name[len..$];
				auto idx = postFix.indexOf("_");

				if(idx != -1) {
					line = postFix[0..idx].to!size_t;
				}
			} catch(Exception e) {
				return SourceLocation();
			}

			return SourceLocation(fileName, line);
		}

		Label[] testLabels(alias test)() {
			Label[] labels;

			foreach (attr; __traits(getAttributes, test)) {
				static if (__traits(hasMember, attr, "labels")) {
					labels ~= attr.labels;
				}
			}

			return labels;
		}

		auto addTestCases(string file, alias moduleName, composite...)() if (composite.length == 1 && isUnitTestContainer!(composite))
		{
			Comment[] comments = file.readText.compressComments;

			foreach (test; __traits(getUnitTests, composite)) {
				auto testCase = TestCase(moduleName, testName!(test)(comments), {
					test();
				}, testLabels!(test));

				testCase.location = testSourceLocation!test(file);

				testCases[moduleName][test.mangleof] = testCase;
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
		enum isUnitTestContainer = true;
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

/// This adds asserts to the module
version(unittest) {
	import fluent.asserts;
}

/// It should find this test
unittest
{
	auto testDiscovery = new UnitTestDiscovery;

	testDiscovery.addModule!(__FILE__, "trial.discovery.unit");

	testDiscovery.testCases.keys.should.contain("trial.discovery.unit");

	testDiscovery.testCases["trial.discovery.unit"].values.map!"a.name".should.contain("It should find this test");
}

/// It should find this flaky test
@Flaky
unittest {
	auto testDiscovery = new UnitTestDiscovery;

	testDiscovery.addModule!(__FILE__, "trial.discovery.unit");

	testDiscovery.testCases.keys.should.contain("trial.discovery.unit");

	auto r = testDiscovery.testCases["trial.discovery.unit"].values.filter!(a => a.name == "It should find this flaky test");

	r.empty.should.equal(false).because("a flaky test is in this module");
	r.front.labels.map!(a => a.name).should.equal(["status_details"]);
	r.front.labels[0].value.should.equal("flaky");
}

/// It should find the line of this test
unittest {
	enum line = __LINE__;
	auto testDiscovery = new UnitTestDiscovery;

	testDiscovery.addModule!(__FILE__, "trial.discovery.unit");

	testDiscovery.testCases.keys.should.contain("trial.discovery.unit");

	auto r = testDiscovery.testCases["trial.discovery.unit"].values.filter!(a => a.name == "It should find the line of this test");

	r.empty.should.equal(false).because("the location should be present");
	r.front.location.fileName.should.endWith("unit.d");
	r.front.location.line.should.equal(line - 1);
}

/// It should find this test with issues attributes
@Issue("1") @Issue("2")
unittest {
	auto testDiscovery = new UnitTestDiscovery;

	testDiscovery.addModule!(__FILE__, "trial.discovery.unit");

	testDiscovery.testCases.keys.should.contain("trial.discovery.unit");

	auto r = testDiscovery.testCases["trial.discovery.unit"].values.filter!(a => a.name == "It should find this test with issues attributes");

	r.empty.should.equal(false).because("an issue test is in this module");
	r.front.labels.map!(a => a.name).should.equal(["issue", "issue"]);
	r.front.labels.map!(a => a.value).should.equal(["1", "2"]);
}

/// The discoverTestCases should find the test with issues attributes
unittest {
	immutable line = __LINE__ - 1;
	auto testDiscovery = new UnitTestDiscovery;

	auto tests = testDiscovery.discoverTestCases(__FILE__);
	tests.length.should.be.greaterThan(0);

	auto testFilter = tests.filter!(a => a.name == "It should find this test with issues attributes");
	testFilter.empty.should.equal(false);

	auto theTest = testFilter.front;

	theTest.labels.map!(a => a.name).should.equal(["issue", "issue"]);
	theTest.labels.map!(a => a.value).should.equal(["1", "2"]);
}

/// The discoverTestCases should find the test with the flaky attribute
unittest {
	immutable line = __LINE__ - 1;
	auto testDiscovery = new UnitTestDiscovery;

	auto tests = testDiscovery.discoverTestCases(__FILE__);
	tests.length.should.be.greaterThan(0);

	auto testFilter = tests.filter!(a => a.name == "It should find this flaky test");
	testFilter.empty.should.equal(false);

	auto theTest = testFilter.front;

	theTest.labels.map!(a => a.name).should.equal(["flaky"]);
	theTest.labels.map!(a => a.value).should.equal([""]);
}

@( "", "The discoverTestCases should find the test with the string attribute name")
unittest {
	immutable line = __LINE__ - 1;
	auto testDiscovery = new UnitTestDiscovery;

	auto tests = testDiscovery.discoverTestCases(__FILE__);
	tests.length.should.be.greaterThan(0);

	auto testFilter = tests.filter!(a => a.name == "The discoverTestCases should find the test with the string attribute name");
	testFilter.empty.should.equal(false);

	testFilter.front.labels.length.should.equal(0);
}

/// The discoverTestCases
/// should find this test
unittest {
	immutable line = __LINE__ - 1;
	auto testDiscovery = new UnitTestDiscovery;

	auto tests = testDiscovery.discoverTestCases(__FILE__);
	tests.length.should.be.greaterThan(0);

	auto testFilter = tests.filter!(a => a.name == "The discoverTestCases should find this test");
	testFilter.empty.should.equal(false);

	auto thisTest = testFilter.front;

	thisTest.suiteName.should.equal("trial.discovery.unit");
	thisTest.location.fileName.should.equal(__FILE__);
	thisTest.location.line.should.equal(line);
}

/// discoverTestCases should ignore version(unittest)
unittest {
	auto testDiscovery = new UnitTestDiscovery;

	auto tests = testDiscovery.discoverTestCases(__FILE__);
	tests.length.should.be.greaterThan(0);

	auto testFilter = tests.filter!(a => a.name == "This adds asserts to the module");
	testFilter.empty.should.equal(true);
}

unittest {
	/// discoverTestCases should set the default test names
	immutable line = __LINE__ - 2;
	auto testDiscovery = new UnitTestDiscovery;

	testDiscovery.discoverTestCases(__FILE__).map!(a => a.name).array.should.contain("__unittestL" ~ line.to!string);
}
