# Executors

[up](../README.md)
Here are informations about how the tests are executed and how you can extend this behaviour.

## Summary

  - [About](#about)
  - [The default executor](#the-default-executor)
  - [Parallel executor](#parallel-executor)
  - [Extending](#extending)


## About

An `Executor` is a class that runs the tests and it must implement the [ITestExecutor](http://trial.szabobogdan.com/docs/trial/interfaces/ITestExecutor.html) 
interface. 

## The default executor

The default test executor runs test in sequential order in a single thread. You don't have to do anything to use this executor.

## Parallel executor

The parallel executor run the tests in parallel. In order to use this executor, you have to set in your `trial.json` the `runInParallel` flag to `true`. The `maxThreads` will set determine how many threads will be used in the same time. Any value that's equal or les than `0` will set the number of threads equal to the number of the threads that your CPU supports.

This executor is experimental and it does not work with all reporters.

## Extending

In order to write your executor, your class must implement the `ITestExecutor` method.

If you want to use your custom test executor, you can replace the default one by adding it to the `LifeCycleListeners`:

```
  static this() {
    LifeCycleListeners.instance.add(new MyCustomExecutor);
  }
```

Be aware that by adding a test executor, you will replace the previous one, since it does not make sense to have more than
one executor at a time.