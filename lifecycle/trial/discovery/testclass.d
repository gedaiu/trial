/++
  A module containing the discovery logic for classes annodated with @Test

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.discovery.testclass;

import std.meta;
import std.traits;

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

      pragma(msg, "===>", classList);

      foreach(className; classList) {
        mixin("alias CurrentClass = " ~ ModuleName ~ "." ~ className ~ ";");

        enum members = __traits(allMembers, CurrentClass);

        foreach(member; members) {
          static if(isTestMember!(ModuleName, className, member)) {
            list ~= TestCase("", "", ({

            }), [ ]);
          }
        }
      }
    }
  }
}

bool isTestMember(string ModuleName, string className, string member)() {
  pragma(msg, className, ":", member);
  mixin("import " ~ ModuleName ~ ";");
  mixin("enum attributes = __traits(getAttributes, " ~ ModuleName ~ "." ~ className ~ "." ~ member ~ ");");

  pragma(msg, member, attributes.stringof, testAttributes!attributes);

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

    @Test()
    void aSimpleTest() {

    }
  }
}

/// It should find the Test Suite class
unittest {
  auto discovery = new TestClassDiscovery();
  discovery.addModule!(`lifecycle/trial/discovery/testclass.d`, `trial.discovery.testclass`);

  discovery.getTestCases.length.should.equal(1);
}