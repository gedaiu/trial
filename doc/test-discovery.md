# Test Discovery

[up](../README.md)

Here are informations about how this runner searces for tests inside your project.

## Summary

  - [About](#about)
  - [Unit Test discovery](#unit-test-discovery)
  - [Test Class discovery](#test-class-discovery)
  - [Spec](#spec)
  - [Extending](#extending)

## About

The test discovery happens at `compile-time`. In order to generate the appropiate code, the
runner has to know about all the test discovery classes that you want to use. You can specify the test discoveries
in the `trial.json` file. The `testDiscovery` list should contain all the test discoveries classes that you need.

The default value is:

```json
"testDiscovery": [
    "trial.discovery.unit.UnitTestDiscovery"
],
```

which will use the `UnitTestDiscovery` class from the `trial.discovery.unit` module.

## Unit Test Discovery

This is the default test discovery. It will search inside your modules for `unittest` blocks. You can add custom names
to your tests by adding a comment before the `unittest` keyword or you annotate
the test with a string [UDA](http://dlang.org/spec/attribute.html#uda) that string will be used as the test name.

```d
/// This is my awesome test
unittest {

}
```

or

```d
@("This is my awesome test")
unittest {

}
```

## Test Class discovery

Test class discovery search for classes annotated with `@Test()`. This discovery method is inspired from the `xUnit` frameworks, that usualy uses oop concepts to write the tests. In order to use this discovery, you need to add the `trial:lifecycle` dependency.

In order to use this discovery method, you need to add `"trial.discovery.testclass.TestClassDiscovery"` to the `trial.json` file.

```json
"testDiscovery": [
    "trial.discovery.testclass.TestClassDiscovery"
],
```

There are a bunch of other [annotations](http://trial.szabobogdan.com/api/trial/discovery/testclass.html) that are useful.

```d
class OtherTestSuite {
    @BeforeEach()
    void beforeEach() {
        ...
    }

    @AfterEach()
    void afterEach() {
        ...
    }

    @BeforeAll()
    void beforeAll() {
        ...
    }

    @AfterAll()
    void afterAll() {
        ...
    }

    @Test()
    @("Some other name")
    void aCustomTest() {
        ...
    }
}
```

## Spec

The spec tests must be written using the `Spec` template, which expects a `function` that will contain your suites.

A test suite begins with a call to the global function `describe` with two parameters: a `string` and a `function`. The `string`
is a name or title for a spec suite - usually what is being tested. The `function` is a block of code that implements the suite.

Specs are defined by calling the global function `it`, which, like `describe` takes a `string` and a `function`. The `string` is the title of the spec and the function is the spec, or test. A spec contains one or more expectations that test the state of the code. An expectation is an assertion that is either `true` or `false`. A spec with all true expectations is a passing spec. A spec with one or more false expectations is a failing spec.

Example:
```d

version (unittest)
{
  import fluent.asserts;
  import trial.discovery.spec;

  private static string trace;

  private alias suite = Spec!({
    describe("Algorithm", {
        it("should return false when the value is not present", {
            [1, 2, 3].canFind(4).should.equal(false);
        });

        describe("Other suite", {
        ...
        });
      ...
    });

    describe("Other suite", {
        ...
    });
  });
}
```

### Setup and Teardown

To help a test suite DRY up any duplicated setup and teardown code, You can use the global `before`, `after`, `beforeEach` and
`afterEach` functions. As the name implies, the `before` function is called once before a suite starts, the `after` function is called after all thest from a suite were ran, the `beforeEach` function is called once before each `spec` in the `describe` in which it is called, and the `afterEach` function is called once after each `spec`.

Example:
```d

version (unittest)
{
  import fluent.asserts;

  private static string trace;

  private alias suite = Spec!({
    describe("My suite", {
        before({
            /// some setup
        });

        after({
            /// some teardown
        });

        beforeEach({
            /// some setup
        });

        afterEach({
            /// some teardown
        });

        it("should run the setup and teardown steps", {
            ...
        });
    });
  });
}
```

In order to use this discovery method, you need to add `"trial.discovery.spec.SpecTestDiscovery"` to the `trial.json` file.

```json
"testDiscovery": [
    "trial.discovery.spec.SpecTestDiscovery"
],
```

## Extending

If you want to write your custom TestDiscovery, your class must implement
the [ITestDiscovery](http://trial.szabobogdan.com/api/trial/interfaces/ITestDiscovery.html) interface and
the `void addModule(string file, string name)()` method which will be called by the runner to help you to search inside modules.

At the compile time, the runner will generate a code similar to this:

```d
void main() {
    ...

    auto testDiscovery0 = new UnitTestDiscovery;8

    testDiscovery0.addModule!("/Users/doe/project/some/module.d", "some.module");
    testDiscovery0.addModule!("/Users/doe/project/other/module.d", "other.module");

    LifeCycleListeners.instance.add(testDiscovery0);

    ...
}

```
