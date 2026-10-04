# Test Discovery

[up](../README.md)

Here are informations about how this runner searces for tests inside your project.

## Summary

  - [About](#about)
  - [Unit Test discovery](#unit-test-discovery)
  - [Spec](#spec)
  - [Extending](#extending)

## About

The test discovery happens at `compile-time`. When you run `dub test`, the runner looks inside every
module of your project with two discoveries, which are always enabled:

  - `UnitTestDiscovery` for `unittest` blocks
  - `SpecTestDiscovery` for `Spec` suites

Only the tests from your own project's modules are run. Tests and `Spec` suites that live in your dependencies, including
trial itself, are not part of your test run.

## Unit Test Discovery

This is the default test discovery. It will search inside your modules for `unittest` blocks. You can add custom names
to your tests by adding a comment before the `unittest` keyword or you annotate
the test with a string [UDA](http://dlang.org/spec/attribute.html#uda) that string will be used as the test name.

[Project example](https://gitlab.com/szabobogdan3/trial/-/tree/master/examples/unittest)

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

## Spec

The spec tests must be written using the `Spec` template, which expects a `function` that will contain your suites.

A test suite begins with a call to the global function `describe` with two parameters: a `string` and a `function`. The `string`
is a name or title for a spec suite - usually what is being tested. The `function` is a block of code that implements the suite.

Specs are defined by calling the global function `it`, which, like `describe` takes a `string` and a `function`. The `string` is the title of the spec and the function is the spec, or test. A spec contains one or more expectations that test the state of the code. An expectation is an assertion that is either `true` or `false`. A spec with all true expectations is a passing spec. A spec with one or more false expectations is a failing spec.

[Project example](https://gitlab.com/szabobogdan3/trial/-/tree/master/examples/spec)

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
```

## Extending

If you want to write your custom TestDiscovery, your class must implement
the [ITestDiscovery](http://trial.szabobogdan.com/api/trial/interfaces/ITestDiscovery.html) interface, whose
`getTestCases` method returns the tests that will be run. Register it from a module constructor:

```d
static this() {
    LifeCycleListeners.instance.add(new MyTestDiscovery);
}
```
