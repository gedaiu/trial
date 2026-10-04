# Extending

[up](../README.md)

Here is how you can add your own reporters, executors and test discoveries to a test run.

## Summary

  - [About](#about)
  - [Example](#example)
  - [Sharing an extension](#sharing-an-extension)

## About

Everything that happens during a run is an event sent to the listeners registered in `LifeCycleListeners.instance`.
The reporters, the executors and the test discoveries that come with trial are listeners too. To extend a run, write a
class that implements the interfaces you need and register it from a module constructor. Trial runs your constructor
before the tests start, because the module is part of your test build.

If you want to see a complete list of the listeners that you can implement, check the
[interfaces api page](http://trial.szabobogdan.com/api/trial/interfaces.html).

## Example

```d
module myproject.testreporter;

version (unittest):

import trial.interfaces;

/// Add your listeners to the Trial lifecycle
static this() {
  LifeCycleListeners.instance.add(new SlowTestReporter);
}

/// Prints the tests that take longer than one second
class SlowTestReporter : ITestCaseLifecycleListener {
  void begin(string suite, ref TestResult test) {
  }

  void end(string suite, ref TestResult test) {
    import std.datetime : seconds;
    import std.stdio : writeln;

    if (test.end - test.begin > 1.seconds) {
      writeln("slow: ", suite, " ", test.name);
    }
  }
}
```

Adding an executor replaces the current one, because a run has only one executor.

## Sharing an extension

To use the same extension in several projects, publish it as a dub package and add it to the `unittest` configuration
of each project next to `trial`. Its module constructor registers the listeners in every project that depends on it.
