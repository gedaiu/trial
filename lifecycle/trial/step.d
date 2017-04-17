module trial.step;

import trial.runner: TestRunner;
import std.stdio;

struct Step
{
  @disable
  this();

  this(string name) {
    TestRunner.instance.beginStep(name);
  }

  ~this() {
    TestRunner.instance.endStep();
  }
}
