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
import std.random;

import trial.interfaces;
import trial.attributes;

/// A structure that stores data about the setup events(methods)
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

private void methodDone(string ModuleName, string ClassName)() {
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

private auto getTestClassInstance(string ModuleName, string ClassName)() {
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

  /// Returns all the test cases that were found in the modules
  /// added with `addModule`
  TestCase[] getTestCases() {
    return list;
  }

  /// Add tests from a certain module
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

///
string getTestName(string ModuleName, string className, string member)() {
  mixin("import " ~ ModuleName ~ ";");
  mixin("enum attributes = __traits(getAttributes, " ~ ModuleName ~ "." ~ className ~ "." ~ member ~ ");");

  enum testAttributes = testAttributes!attributes;

  string name;

  foreach(attribute; attributes) {
    static if(is(typeof(attribute) == string)) {
      name = attribute;
    }
  }

  if(name.length == 0) {
    return member.camelToSentence;
  } else {
    return name;
  }
}

///
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

///
bool isTestMember(string ModuleName, string className, string member)() {
  mixin("import " ~ ModuleName ~ ";");
  mixin("enum attributes = __traits(getAttributes, " ~ ModuleName ~ "." ~ className ~ "." ~ member ~ ");");

  return testAttributes!attributes.length > 0;
}

///
bool isSetupMember(string ModuleName, string className, string member)() {
  mixin("import " ~ ModuleName ~ ";");
  mixin("enum attributes = __traits(getAttributes, " ~ ModuleName ~ "." ~ className ~ "." ~ member ~ ");");

  return setupAttributes!attributes.length > 0;
}

///
template isClass(string name)
{
  mixin("
    static if (is(" ~ name ~ " == class))
      enum bool isClass = true;
    else
      enum bool isClass = false;");
}

///
template isTestAttribute(alias Attribute)
{
  import trial.attributes;

  static if(!is(CommonType!(Attribute, TestAttribute) == void)) {
    enum bool isTestAttribute = true;
  } else {
    enum bool isTestAttribute = false;
  }
}

///
template isRightParameter(string parameterName) {
  template isRightParameter(alias Attribute) {
    enum isRightParameter = Attribute.parameterName == parameterName;
  }
}

///
template isSetupAttribute(alias Attribute)
{
  static if(!is(CommonType!(Attribute, TestSetupAttribute) == void)) {
    enum bool isSetupAttribute = true;
  } else {
    enum bool isSetupAttribute = false;
  }
}

///
template isValueProvider(alias Attribute) {
  static if(__traits(hasMember, Attribute, "provide") && __traits(hasMember, Attribute, "parameterName")) {
    enum bool isValueProvider = true;
  } else {
    enum bool isValueProvider = false;
  }
}

///
template extractClasses(string moduleName, members...)
{
  alias Filter!(isClass,members) extractClasses;
}

///
template extractValueProviders(Elements...)
{
  alias Filter!(isValueProvider, Elements) extractValueProviders;
}

///
template testAttributes(attributes...)
{
  alias Filter!(isTestAttribute, attributes) testAttributes;
}

///
template setupAttributes(attributes...)
{
  alias Filter!(isSetupAttribute, attributes) setupAttributes;
}

///
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

    @Test()
    @("Some other name")
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

private string generateRandomParameters(alias T, int index)() pure nothrow {
  alias paramTypes = Parameters!T;
  enum params = ParameterIdentifierTuple!T;
  alias providers = Filter!(isRightParameter!(params[index].stringof[1..$-1]), extractValueProviders!(__traits(getAttributes, T)));

  enum provider = "Filter!(isRightParameter!(" ~ params[index].stringof ~ "), extractValueProviders!(__traits(getAttributes, T)))";

  static if(providers.length > 0) {
    immutable string definition = "auto param_" ~ params[index] ~ " = " ~ provider ~ "[0]().provide; ";
  } else {
    immutable string definition = "auto param_" ~ params[index] ~ " = uniform!" ~ paramTypes[index].stringof ~ "(); ";
  }

  static if(index == 0) {
    return definition;
  } else {
    return definition ~ generateRandomParameters!(T, index-1);
  }
}

private string generateMethodParameters(alias T, int size)() {
  enum params = ParameterIdentifierTuple!T;

  static if(size == 0) {
    return "";
  } else static if(size == 1) {
    return "param_" ~ params[0];
  } else {
    return generateMethodParameters!(T, size - 1) ~ ", param_" ~ params[size - 1];
  }
}

/// Call a method using the right data provders
void methodCaller(alias T, U)(U func) {
  enum parameterCount = arity!T;

  mixin(generateRandomParameters!(T, parameterCount - 1));
  mixin("func(" ~ generateMethodParameters!(T, parameterCount) ~ ");");
}

/// methodCaller should call the method with random numeric values
unittest {
  class TestClass {
    static int usedIntValue = 0;
    static ulong usedUlongValue = 0;

    void randomMethod(int value, ulong other) {
      usedIntValue = value;
      usedUlongValue = other;
    }
  }

  auto instance = new TestClass;

  methodCaller!(instance.randomMethod)(&instance.randomMethod);

  TestClass.usedIntValue.should.not.equal(0);
  TestClass.usedUlongValue.should.not.equal(0);
}

struct ValueProvider(string name, alias T) {
  immutable static string parameterName = name;

  auto provide() {
    return T();
  }
}

auto For(string name, alias T)() {
  return ValueProvider!(name, T)();
}

version(unittest) {
  auto someCustomFunction() {
    return 6;
  }
}

/// methodCaller should call the method with custom random generators
unittest {
  class TestClass {
    static int usedIntValue = 0;
    static ulong usedUlongValue = 0;

    @For!("value", { return 5; })
    @For!("other", { return someCustomFunction(); })
    void randomMethod(int value, ulong other) {
      usedIntValue = value;
      usedUlongValue = other;
    }
  }

  auto instance = new TestClass;

  methodCaller!(instance.randomMethod)(&instance.randomMethod);

  TestClass.usedIntValue.should.equal(5);
  TestClass.usedUlongValue.should.equal(6);
}