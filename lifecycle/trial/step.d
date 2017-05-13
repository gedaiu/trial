module trial.step;

import trial.runner;
import trial.interfaces;
import std.datetime;

struct Step
{
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

    LifeCycleListeners.instance.begin(step);
  }

  ~this() {
    step.end = Clock.currTime;
    LifeCycleListeners.instance.end(step);
  }
}
