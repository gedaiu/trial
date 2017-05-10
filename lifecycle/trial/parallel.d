module trial.parallel;

import trial.interfaces;
import trial.discovery;
import trial.runner;

class ParallelExecutor : ITestExecutor {
  SuiteResult[] execute(TestCase testCase) {
    import std.parallelism;
    SuiteResult[] result;

    task({
      testCase.func();
    }).executeInNewThread();

    return result;
  }
}

version(unittest) {
  import fluent.asserts;
  import core.thread;
  import trial.step;

  void stepMock2() @system {
    Thread.sleep(100.msecs);
    auto a = Step("some step");
    executed = true;

    for(int i=0; i<3; i++) {
      Thread.sleep(100.msecs);
      stepFunction(i);
      Thread.sleep(100.msecs);
    }
  }

  void stepMock3() @system {
    Thread.sleep(120.msecs);
    auto a = Step("some step");
    executed = true;

    for(int i=0; i<3; i++) {
      Thread.sleep(120.msecs);
      stepFunction(i);
      Thread.sleep(120.msecs);
    }
  }
}
/*
@("A parallel executor should call the events in the right order")
unittest
{
  import core.thread;

  executed = false;
  string[] steps;
  class MockListener : IStepLifecycleListener, ITestCaseLifecycleListener, ISuiteLifecycleListener {
      void begin(ref StepResult step) {
        steps ~= [ "begin " ~ step.name ];
      }
      void end(ref StepResult step) {
        steps ~= [ "end " ~ step.name ];
      }

      void begin(ref TestResult test) {
        steps ~= [ "begin " ~ test.name ];
      }

      void end(ref TestResult test) {
        steps ~= [ "end " ~ test.name ];
      }

      void begin(ref SuiteResult suite) {
        steps ~= [ "begin " ~ suite.name ];
      }

      void end(ref SuiteResult suite) {
        steps ~= [ "end " ~ suite.name ];
      }
  }

  TestCase[] tests = [ TestCase("test1", &stepMock2), TestCase("test2", &stepMock3) ];

  auto old = LifeCycleListeners.instance;
  scope(exit) {
    LifeCycleListeners.instance = old;
  }

  LifeCycleListeners.instance = new LifeCycleListeners;

  LifeCycleListeners.instance.add(new MockListener);
  LifeCycleListeners.instance.add(new ParallelExecutor);

  SuiteRunner suiteRunner = new SuiteRunner("suite name4", tests);

  suiteRunner.start();

  Thread.sleep(2.seconds);
  executed.should.equal(true);
  steps.should.equal([ "begin suite name4",
    "begin test1", "begin some step",
    "begin test2", "end test1", "end test2", "end suite name4" ]);
}
*/
