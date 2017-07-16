/++
  A module containing the discovery logic for classes annodated with @Test

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.discovery.testclass;

import std.meta;
import std.traits;
import std.uni;
import std.conv;
import std.string;
import std.algorithm;

import trial.interfaces;

/// The default test discovery looks for unit test sections and groups them by module
class TestClassDiscovery : ITestDiscovery {
  private TestCase[] list;

  TestCase[] getTestCases() {
    return list;
  }

  void addModule(string file, string moduleName)()
  {
    discover!moduleName;
  }

  private {
    void discover(string ModuleName)() {
      mixin("import " ~ ModuleName ~ ";");
      enum classList = classMembers!(ModuleName);

      foreach(className; classList) {
        mixin("alias CurrentClass = " ~ ModuleName ~ "." ~ className ~ ";");

        enum members = __traits(allMembers, CurrentClass);

        foreach(member; members) {
          static if(isTestMember!(ModuleName, className, member)) {
            string testName = getTestName!(ModuleName, className, member);

            list ~= TestCase(ModuleName ~ "." ~ className, testName, ({
              mixin(`auto instance = new ` ~ className ~ `();`);
              mixin(`instance.` ~ member ~ `;`);
            }), [ ]);
          }
        }
      }
    }
  }
}

string getTestName(string ModuleName, string className, string member)() {
  mixin("import " ~ ModuleName ~ ";");
  mixin("enum attributes = __traits(getAttributes, " ~ ModuleName ~ "." ~ className ~ "." ~ member ~ ");");

  enum testAttributes = testAttributes!attributes;
  enum name = testAttributes[0].name;

  static if(name.length == 0) {
    return member.camelToSentence;
  } else {
    return name;
   }
}

/// Converts a string from camel notation to a readable sentence
string camelToSentence(const string name) pure {
  string sentence;

  foreach(ch; name) {
    if(ch.toUpper == ch) {
      sentence ~= " " ~ ch.toLower.to!string;
    } else {
      sentence ~= ch;
    }
  }

  return sentence.capitalize;
}

bool isTestMember(string ModuleName, string className, string member)() {
  mixin("import " ~ ModuleName ~ ";");
  mixin("enum attributes = __traits(getAttributes, " ~ ModuleName ~ "." ~ className ~ "." ~ member ~ ");");

  return testAttributes!attributes.length > 0;
}

template isClass(string name)
{
  mixin("
    static if (is(" ~ name ~ " == class))
      enum bool isClass = true;
    else
      enum bool isClass = false;");
}

template isTestAttribute(alias Attribute)
{
  import trial.attributes;

  pragma(msg, Attribute, "?", CommonType!(Attribute, TestAttribute));

  static if(!is(CommonType!(Attribute, TestAttribute) == void)) {
    enum bool isTestAttribute = true;
  } else {
    enum bool isTestAttribute = false;
  }
}

template extractClasses(string moduleName, members...)
{
  alias Filter!(isClass,members) extractClasses;
}

template testAttributes(attributes...)
{
  alias Filter!(isTestAttribute, attributes) testAttributes;
}

template classMembers(string moduleName)
{
    mixin("alias extractClasses!(moduleName, __traits(allMembers, " ~ moduleName ~ ")) classMembers;");
}

version(unittest) {
  import trial.attributes;
  import fluent.asserts;

  class SomeTestSuite {
    static string lastTest;

    @Test()
    void aSimpleTest() {
      lastTest = "a simple test";
    }
  }

  class OtherTestSuite {

    @Test("Some other name")
    void aCustomTest() {

    }
  }
}

/// It should find the Test Suite class
unittest {
  auto discovery = new TestClassDiscovery();
  discovery.addModule!(`lifecycle/trial/discovery/testclass.d`, `trial.discovery.testclass`);

  auto testCases = discovery.getTestCases;

  testCases.length.should.equal(2);
  testCases[0].suiteName.should.equal(`trial.discovery.testclass.SomeTestSuite`);
  testCases[0].name.should.equal(`A simple test`);

  testCases[1].suiteName.should.equal(`trial.discovery.testclass.OtherTestSuite`);
  testCases[1].name.should.equal(`Some other name`);
}

/// It should execute tests from a Test Suite class
unittest {
  auto discovery = new TestClassDiscovery();
  discovery.addModule!(`lifecycle/trial/discovery/testclass.d`, `trial.discovery.testclass`);

  auto test = discovery.getTestCases
    .filter!(a => a.suiteName == `trial.discovery.testclass.SomeTestSuite`)
    .filter!(a => a.name == `A simple test`)
    .front;

  test.func();

  SomeTestSuite.lastTest.should.equal("a simple test");
}