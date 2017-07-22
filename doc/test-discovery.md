# Test Discovery

[up](../README.md)

Here are informations about how this runner searces for tests inside your project.

## Summary

  - [About](#about)
  - [Unit Test discovery](#unit-test-discovery)
  - [Test Class discovery](#test-class-discovery)
  - [Extending](#extending)

## About

The test discovery happens at `compile-time`. In order to generate the appropiate code, the
runner has to know about all the test discovery classes that you want to use. You can specify the test discoveries
in the `trial.json` file. The `testDiscovery` list should contain all the test discoveries classes that you need.

The default value is:

```
    "testDiscovery": [
        "trial.discovery.unit.UnitTestDiscovery"
    ],
```

which will use the `UnitTestDiscovery` class from the `trial.discovery.unit` module.

## Unit Test Discovery

This is the default test discovery. It will search inside your modules for `unittest` blocks. You can add custom names
to your tests by adding a comment before the `unittest` keyword or you annotate
the test with a string [UDA](http://dlang.org/spec/attribute.html#uda) that string will be used as the test name.

```
/// This is my awesome test
unittest {

}
```

or

```
@("This is my awesome test")
unittest {

}
```

## Test Class discovery

Test class discovery search for classes annotated with `@Test()`. This discovery method is inspired from the `xUnit` frameworks, that usualy uses oop concepts to write the tests. In order to use this discovery, you need to add the `trial:lifecycle` dependency.

In order to use this discovery method, you need to add `"trial.discovery.discovery.TestClassDiscovery"` to the `trial.json` file.

```
    "testDiscovery": [
        "trial.discovery.discovery.TestClassDiscovery"
    ],
```

There are a bunch of other (annotations)[http://trial.szabobogdan.com/api/trial/discovery/testclass.html] that are useful.

```
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

## Extending

If you want to write your custom TestDiscovery, your class must implement
the (ITestDiscovery)[http://trial.szabobogdan.com/api/trial/interfaces/ITestDiscovery.html] interface and
the `void addModule(string file, string name)()` method which will be called by the runner to help you to search inside modules.

At the compile time, the runner will generate a code similar to this:

```
void main() {
    ...

    auto testDiscovery0 = new UnitTestDiscovery;8

    testDiscovery0.addModule!("/Users/doe/project/some/module.d", "some.module");
    testDiscovery0.addModule!("/Users/doe/project/other/module.d", "other.module");

    LifeCycleListeners.instance.add(testDiscovery0);

    ...
}

```