module trial.step;

import trial.runner;
import trial.interfaces;
import std.datetime;
import std.stdio;

struct Step
{
  static {
    string suite;
    string test;
  }

  @disable
  this();

  private {
    StepResult step;
  }

  this(string name) {
    step = new StepResult;
    step.name = name;
    step.begin = Clock.currTime;
    step.end = Clock.currTime;

    if(LifeCycleListeners.instance is null) {
      writeln("Warning! Can not set steps if the LifeCycleListeners.instance is not set.");
      return;
    }

    LifeCycleListeners.instance.begin(suite, test, step);
  }

  ~this() {
    if(LifeCycleListeners.instance is null) {
      writeln("Warning! Can not set steps if the LifeCycleListeners.instance is not set.");
      return;
    }

    step.end = Clock.currTime;
    LifeCycleListeners.instance.end(suite, test, step);
  }
}
