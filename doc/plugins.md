# Attachments

[up](../README.md)

Here are informations about how you can write plugins.

## Summary

  - [About](#about)
  - [Example plugin](#example-plugin)
  - [Module names](#module-names)

## About

When you want to extend the runner, but you don't want to add a dependency to your `dub.json` file, you
can write a plugin. This is a way of extending the test run with external libraries that are published on
[code.dlang.org](http://code.dlang.org).

To attach a plugin to your run, run:

```
trial -p plugin1,plugin2,plugin3...
```

## Example plugin

```d
module trialcustom.plugin;

import trial.interfaces;

/// Add your listeners to the Trial lifecycle
static this() {
  LifeCycleListeners.instance.add(new TrialCustomPlugin());
}

/// Implement your listeners
class RazerReporter : ITestCaseLifecycleListener, ILifecycleListener {
    ... 
}
```

If you want to see a complete list of the listeners that you can implement, check the [interfaces api page](http://trial.szabobogdan.com/api/trial/interfaces.html).

## Module names

Your plugin can have `-` and `:` in the name. The `:` will add as a dependency a subpackage. In order to have your module
initialized, Trial will import your module in the generated main file. For example:

```
trial -p my-plugin:core
``` 

will download the `core` subpackage from `my-plugin` package, and it will import `myplugin.core` in the main file.