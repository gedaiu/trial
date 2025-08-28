module trial.discovery.unit;
/++
  A module containing parsing code utilities

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/

import trial.testNameProvider;
import std.string;
import std.traits;
import std.conv;
import std.array;
import std.file;
import std.algorithm;
import std.range;
import std.typecons;
import std.math;

import trial.interfaces;
import trial.discovery.code;



Comment[] commentGroupToString(T)(T[] group)
{
  if (group.front[1] == CommentType.comment)
  {
    auto slice = group.until!(a => a[1] != CommentType.comment).array;

    string value = slice.map!(a => a[2].stripLeft('/').array.to!string).map!(a => a.strip)
      .join(' ').array.to!string;

    return [Comment(slice[slice.length - 1][0], value)];
  }

  if (group.front[1] == CommentType.begin)
  {
    auto ch = group.front[2][1];
    auto index = 0;

    auto newGroup = group.map!(a => Tuple!(int, CommentType, immutable(char),
        string)(a[0], a[1], a[2].length > 2 ? a[2][1] : ' ', a[2])).array;

    foreach (item; newGroup)
    {
      index++;
      if (item[1] == CommentType.end && item[2] == ch)
      {
        break;
      }
    }

    auto slice = group.map!(a => Tuple!(int, CommentType, immutable(char), string)(a[0],
        a[1], a[2].length > 2 ? a[2][1] : ' ', a[2])).take(index);

    string value = slice.map!(a => a[3].strip).map!(a => a.stripLeft('/')
        .stripLeft(ch).array.to!string).map!(a => a.strip).join(' ')
      .until(ch ~ "/").array.stripRight('/').stripRight(ch).strip.to!string;

    return [Comment(slice[slice.length - 1][0], value)];
  }

  return [];
}

/// The default test discovery looks for unit test sections and groups them by module
class UnitTestDiscovery : ITestDiscovery
{
  TestCase[string][string] testCases;

  TestCase[] getTestCases()
  {
    return testCases.values.map!(a => a.values).joiner.array;
  }

  void addModule(string file, string moduleName)()
  {
    mixin("import " ~ moduleName ~ ";");
    mixin("discover!(`" ~ file ~ "`, `" ~ moduleName ~ "`, " ~ moduleName ~ ")(0);");
  }

  private
  {
    SourceLocation testSourceLocation(alias test)(string fileName)
    {
      auto location = __traits(getLocation, test);

      return SourceLocation(location[0], location[1]);
    }

    Label[] testLabels(alias test)()
    {
      Label[] labels;

      foreach (attr; __traits(getAttributes, test))
      {
        static if (__traits(hasMember, attr, "labels"))
        {
          labels ~= attr.labels;
        }
      }

      return labels;
    }

    void addTestCases(string file, alias moduleName, composite...)()
        if (composite.length == 1 && isUnitTestContainer!(composite))
    {
      static if( !composite[0].stringof.startsWith("package") && std.traits.moduleName!composite != moduleName ) {
        return;
      } else {
        foreach (test; __traits(getUnitTests, composite))
        {
          auto testCase = TestCase(moduleName, TestNameProvider.instance.getName!test, {
            test();
          }, testLabels!(test));

          testCase.location = testSourceLocation!test(file);

          testCases[moduleName][test.mangleof] = testCase;
        }
      }
    }

    void discover(string file, alias moduleName, composite...)(int index)
        if (composite.length == 1 && isUnitTestContainer!(composite))
    {
      if(index > 10) {
        return;
      }

      addTestCases!(file, moduleName, composite);

      static if (isUnitTestContainer!composite)
      {
        foreach (member; __traits(allMembers, composite))
        {
          static if(!is( typeof(__traits(getMember, composite, member)) == void)) {
            static if (__traits(compiles, __traits(getMember, composite, member))
                && isSingleField!(__traits(getMember, composite, member)) && isUnitTestContainer!(__traits(getMember,
                  composite, member)) && !isModule!(__traits(getMember, composite, member)))
            {
              if (__traits(getMember, composite, member).mangleof !in testCases)
              {
                discover!(file, moduleName, __traits(getMember, composite, member))(index + 1);
              }
            }
          }
        }
      }
    }
  }
}

private template isUnitTestContainer(DECL...) if (DECL.length == 1)
{
  static if (!isAccessible!DECL)
  {
    enum isUnitTestContainer = false;
  }
  else static if (is(FunctionTypeOf!(DECL[0])))
  {
    enum isUnitTestContainer = false;
  }
  else static if (is(DECL[0]) && !isAggregateType!(DECL[0]))
  {
    enum isUnitTestContainer = false;
  }
  else static if (isPackage!(DECL[0]))
  {
    enum isUnitTestContainer = true;
  }
  else static if (isModule!(DECL[0]))
  {
    enum isUnitTestContainer = DECL[0].stringof != "module object";
  }
  else static if (!__traits(compiles, fullyQualifiedName!(DECL[0])))
  {
    enum isUnitTestContainer = false;
  }
  else static if (!is(typeof(__traits(allMembers, DECL[0]))))
  {
    enum isUnitTestContainer = false;
  }
  else
  {
    enum isUnitTestContainer = true;
  }
}

private template isModule(DECL...) if (DECL.length == 1)
{
  static if (is(DECL[0]))
    enum isModule = false;
  else static if (is(typeof(DECL[0])) && !is(typeof(DECL[0]) == void))
    enum isModule = false;
  else static if (!is(typeof(DECL[0].stringof)))
    enum isModule = false;
  else static if (is(FunctionTypeOf!(DECL[0])))
    enum isModule = false;
  else
    enum isModule = DECL[0].stringof.startsWith("module ");
}

private template isPackage(DECL...) if (DECL.length == 1)
{
  static if (is(DECL[0]))
    enum isPackage = false;
  else static if (is(typeof(DECL[0])) && !is(typeof(DECL[0]) == void))
    enum isPackage = false;
  else static if (!is(typeof(DECL[0].stringof)))
    enum isPackage = false;
  else static if (is(FunctionTypeOf!(DECL[0])))
    enum isPackage = false;
  else
    enum isPackage = DECL[0].stringof.startsWith("package ");
}

private template isAccessible(DECL...) if (DECL.length == 1)
{
  enum isAccessible = __traits(compiles, testTempl!(DECL[0])());
}

private template isSingleField(DECL...)
{
  enum isSingleField = DECL.length == 1;
}

private void testTempl(X...)() if (X.length == 1)
{
  static if (is(X[0]))
  {
    auto x = X[0].init;
  }
  else
  {
    auto x = X[0].stringof;
  }
}

/// This adds asserts to the module
version (unittest)
{
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
}

/// It should find this test
unittest
{
  auto testDiscovery = new UnitTestDiscovery;

  testDiscovery.addModule!(__FILE__, "trial.discovery.unit");

  testDiscovery.testCases.keys.should.contain("trial.discovery.unit");

  testDiscovery.testCases["trial.discovery.unit"].values.map!"a.name".should.contain(
      "It should find this test");
}

/// It should find this flaky test
@Flaky unittest
{
  auto testDiscovery = new UnitTestDiscovery;

  testDiscovery.addModule!(__FILE__, "trial.discovery.unit");

  testDiscovery.testCases.keys.should.contain("trial.discovery.unit");

  auto r = testDiscovery.testCases["trial.discovery.unit"].values.filter!(
      a => a.name == "It should find this flaky test");

  r.empty.should.equal(false).because("a flaky test is in this module");
  r.front.labels.map!(a => a.name).should.equal(["status_details"]);
  r.front.labels[0].value.should.equal("flaky");
}

/// It should find the line of this test
unittest
{
  enum line = __LINE__ - 2;
  auto testDiscovery = new UnitTestDiscovery;

  testDiscovery.addModule!(__FILE__, "trial.discovery.unit");

  testDiscovery.testCases.keys.should.contain("trial.discovery.unit");

  auto r = testDiscovery.testCases["trial.discovery.unit"].values.filter!(
      a => a.name == "It should find the line of this test");

  r.empty.should.equal(false).because("the location should be present");
  r.front.location.fileName.should.endWith("unit.d");
  r.front.location.line.should.equal(line);
}

/// It should find this test with issues attributes
@Issue("1") @Issue("2")
unittest
{
  auto testDiscovery = new UnitTestDiscovery;

  testDiscovery.addModule!(__FILE__, "trial.discovery.unit");
  testDiscovery.testCases.keys.should.contain("trial.discovery.unit");

  auto r = testDiscovery.testCases["trial.discovery.unit"].values.filter!(
      a => a.name == "It should find this test with issues attributes");

  r.empty.should.equal(false).because("an issue test is in this module");
  r.front.labels.map!(a => a.name).should.equal(["issue", "issue"]);
  r.front.labels.map!(a => a.value).should.equal(["1", "2"]);
}
