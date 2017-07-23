/++
  When you run complex tests, or tests that take a lot of time, it helps
  to mark certain areas as steps, to ease the debug or to improve the report.

  A good usage is for running BDD tests where a step can be steps from the
  `Gherkin Syntax` or UI Automation tests.

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.step;

import trial.runner;
import trial.interfaces;
import std.datetime;
import std.stdio;

/** A stepstructure. Creating a Step will automatically be added to the current step as a child
  * The steps can be nested to allow you to group steps as with meanigful names.
  *
  * The steps ends when the Struct is destroyed. In order to have a step that represents a method
  * assign it to a local variable
  *
  * Examples:
  * ------------------------
  * void TestSetup() @system
  * {
  *   auto aStep = Step("Given some precondition");
  *
  *   Step("Some setup");
  *   performSomeSetup();
  *
  *   Step("Other setup");
  *   performOtherSetup();
  * }
  * // will create this tree:
  * // Test
  * //  |
  * //  +- Given some precondition
  * //        |
  * //        +- Some setup
  * //        +- Other setup
  * ------------------------
  */
struct Step
{
  static {
    /// The current suite name. Do not alter this global variable
    string suite;
    /// The current test name. Do not alter this global variable
    string test;
  }

  @disable
  this();

  private {
    StepResult step;
  }

  /// Create and attach a step
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

  /// Mark the test as finished
  ~this() {
    if(LifeCycleListeners.instance is null) {
      writeln("Warning! Can not set steps if the LifeCycleListeners.instance is not set.");
      return;
    }

    step.end = Clock.currTime;
    LifeCycleListeners.instance.end(suite, test, step);
  }
}
