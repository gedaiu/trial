# Executors

[up](../README.md)

Here are informations about how the tests are executed and how you can extend this behaviour.

## Summary

  - [About](#about)
  - [The default executor](#the-default-executor)
  - [Parallel executor](#parallel-executor)
  - [Process executor](#process-executor)
  - [Extending](#extending)

## About

An `Executor` is a class that runs the tests and it must implement the [ITestExecutor](http://trial.szabobogdan.com/api/trial/interfaces/ITestExecutor.html)
interface.

## The default executor

The default test executor runs test in sequential order in a single thread. You don't have to do anything to use this executor.

## Parallel executor

The parallel executor run the tests in parallel. In order to use this executor, you have to add in your `trial.json`:
```
  "executor": "parallel"
```
or pass `-e parallel` on the [command line](command-line.md).
The `maxThreads` will set determine how many threads will be used in the same time. Any value that's equal or less than `0` will set the number of threads equal to the number of the threads that your CPU supports.

This executor is experimental and it does not work with all reporters.

## Process executor

This executor runs each test in a separate process, by starting the test executable again with exact filters
(`-s "=<suite>" -t "=<test>"`) so that each child runs exactly one test. A crash, like a segmentation fault, then fails only
that test instead of stopping the whole run. It does not run the processes in parallel.

To use this executor, add in yout `trial.json`:
```
  "executor": "process"
```
or pass `-e process` on the [command line](command-line.md).
## Extending

In order to write your executor, your class must implement the `ITestExecutor` method.

If you want to use your custom test executor, you can replace the default one by adding it to the `LifeCycleListeners`:

```d
static this() {
    LifeCycleListeners.instance.add(new MyCustomExecutor);
}
```

Be aware that by adding a test executor, you will replace the previous one, since it does not make sense to have more than
one executor at a time.
