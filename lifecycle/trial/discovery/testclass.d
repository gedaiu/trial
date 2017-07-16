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

struct SetupEvent {
  string name;

  TestSetupAttribute setup;
  TestCaseFunction func;
}


private {
  SetupEvent[][string] setupMethods;
  Object[string] testClassInstances;
  size_t[string] testMethodCount;
  size_t[string] testMethodExecuted;
}

void methodDone(string ModuleName, string ClassName)() {
  enum key = ModuleName ~ "." ~ ClassName;

  testMethodExecuted[key]++;

  if(testMethodExecuted[key] >= testMethodCount[key]) {
    if(key in setupMethods) {
      foreach(setupMethod; setupMethods[key].filter!(a => a.setup.afterAll)) {
        setupMethod.func();
      }
    }

    testClassInstances.remove(key);
  }
}
auto getTestClassInstance(string ModuleName, string ClassName)() {
  enum key = ModuleName ~ "." ~ ClassName;

  if(key !in testClassInstances) {
    mixin(`import ` ~ ModuleName ~ `;`);
    mixin(`auto instance = new ` ~ ClassName ~ `();`);

    testClassInstances[key] = instance;
    testMethodExecuted[key] = 0;

    if(key in setupMethods) {
      foreach(setupMethod; setupMethods[key].filter!(a => a.setup.beforeAll)) {
        setupMethod.func();
      }
    }
  }

  mixin(`return cast(` ~ key ~ `) testClassInstances[key];`);
}

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
          static if(isSetupMember!(ModuleName, className, member)) {
            enum setup = getSetup!(ModuleName, className, member);
            enum key = ModuleName ~ "." ~ className;

            auto exists = key in setupMethods && !setupMethods[key].filter!(a => a.name == member).empty;

            if(!exists) {
              setupMethods[key] ~= SetupEvent(member, setup, ({
                mixin(`auto instance = new ` ~ className ~ `();`);
                mixin(`instance.` ~ member ~ `;`);
              }));
            }

            pragma(msg, className, ":", member, ":", setup);
          }
        }
      }

      foreach(className; classList) {
        enum key = ModuleName ~ "." ~ className;
        mixin("alias CurrentClass = " ~ key ~ ";");

        enum members = __traits(allMembers, CurrentClass);
        testMethodCount[key] = 0;

        foreach(member; members) {
          static if(isTestMember!(ModuleName, className, member)) {
            testMethodCount[key]++;
            string testName = getTestName!(ModuleName, className, member);

            list ~= TestCase(ModuleName ~ "." ~ className, testName, ({
              auto instance = getTestClassInstance!(ModuleName, className);

              enum key = ModuleName ~ "." ~ className;

              if(key in setupMethods) {
                foreach(setupMethod; setupMethods[key].filter!(a => a.setup.beforeEach)) {
                  setupMethod.func();
                }
              }

              mixin(`instance.` ~ member ~ `;`);

              if(key in setupMethods) {
                foreach(setupMethod; setupMethods[key].filter!(a => a.setup.afterEach)) {
                  setupMethod.func();
                }
              }

              methodDone!(ModuleName, className);
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

auto getSetup(string ModuleName, string className, string member)() {
  mixin("import " ~ ModuleName ~ ";");
  mixin("enum attributes = __traits(getAttributes, " ~ ModuleName ~ "." ~ className ~ "." ~ member ~ ");");

  return setupAttributes!attributes[0];
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

bool isSetupMember(string ModuleName, string className, string member)() {
  mixin("import " ~ ModuleName ~ ";");
  mixin("enum attributes = __traits(getAttributes, " ~ ModuleName ~ "." ~ className ~ "." ~ member ~ ");");

  return setupAttributes!attributes.length > 0;
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

  static if(!is(CommonType!(Attribute, TestAttribute) == void)) {
    enum bool isTestAttribute = true;
  } else {
    enum bool isTestAttribute = false;
  }
}

template isSetupAttribute(alias Attribute)
{
  import trial.attributes;

  static if(!is(CommonType!(Attribute, TestSetupAttribute) == void)) {
    enum bool isSetupAttribute = true;
  } else {
    enum bool isSetupAttribute = false;
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

template setupAttributes(attributes...)
{
  alias Filter!(isSetupAttribute, attributes) setupAttributes;
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
    static string[] order;

    @BeforeEach()
    void beforeEach() {
      order ~= "before each";
    }

    @AfterEach()
    void afterEach() {
      order ~= "after each";
    }

    @BeforeAll()
    void beforeAll() {
      order ~= "before all";
    }

    @AfterAll()
    void afterAll() {
      order ~= "after all";
    }

    @Test("Some other name")
    void aCustomTest() {
      order ~= "a custom test";
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
  scope(exit) {
    SomeTestSuite.lastTest = "";
  }

  auto discovery = new TestClassDiscovery();
  discovery.addModule!(`lifecycle/trial/discovery/testclass.d`, `trial.discovery.testclass`);

  auto test = discovery.getTestCases
    .filter!(a => a.suiteName == `trial.discovery.testclass.SomeTestSuite`)
    .filter!(a => a.name == `A simple test`)
    .front;

  test.func();

  SomeTestSuite.lastTest.should.equal("a simple test");
}

/// It should execute the before and after methods tests from a Test Suite class
unittest {
  scope(exit) {
    OtherTestSuite.order = [];
  }

  auto discovery = new TestClassDiscovery();
  discovery.addModule!(`lifecycle/trial/discovery/testclass.d`, `trial.discovery.testclass`);

  auto test = discovery.getTestCases
    .filter!(a => a.suiteName == `trial.discovery.testclass.OtherTestSuite`)
    .filter!(a => a.name == `Some other name`)
    .front;

  test.func();

  OtherTestSuite.order.should.equal([ "before all", "before each", "a custom test", "after each", "after all"]);
}