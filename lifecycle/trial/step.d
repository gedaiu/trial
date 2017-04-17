module trial.step;

import trial.runner: TestRunner;
import std.stdio;

struct Step
{
  @disable
  this();

  this(string name) {
    if(TestRunner.instance is null) {
      writeln("Warning: The TestRunner instance is null.");
      return;
    }

    TestRunner.instance.beginStep(name);
  }

  ~this() {
    if(TestRunner.instance is null) {
      writeln("Warning: The TestRunner instance is null.");
      return;
    }

    TestRunner.instance.endStep();
  }
}
