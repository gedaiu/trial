# Test Discovery

[up](../README.md)

Here are informations about how this runner searces for tests inside your project.

## Summary

  - [About](#about)
  - [Unit Test discovery](#unit-test-discovery)
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

This is the default test discovery. It will search inside your modules for `unittest` blocks. If you addnotate
the test with a string [UDA](http://dlang.org/spec/attribute.html#uda) that string will be used as the test name.

## Extending

If you want to write your custom TestDiscovery, your class must implement
the (ITestDiscovery)[http://trial.szabobogdan.com/api/trial/interfaces/ITestDiscovery.html] interface and 
the `void addModule(string name)()` method which will be called by the runner to help you to search inside modules.

At the compile time, the runner will generate a code similar to this:

```
void main() {
    ...

    auto testDiscovery0 = new UnitTestDiscovery;
    
    testDiscovery0.addModule!"some.module";
    testDiscovery0.addModule!"other.module";

    LifeCycleListeners.instance.add(testDiscovery0);

    ...
}

```