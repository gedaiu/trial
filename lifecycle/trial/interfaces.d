/++
  A module containing the interfaces used for extending the test runner
  
  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.interfaces;

import std.datetime;
import std.algorithm;
import std.array;

/// Alias to a Test Case function type
alias TestCaseFunction = void function() @system;

/// A Listener for the main test events
interface ILifecycleListener
{
  /// This method is trigered when before the test start
  void begin(ulong testCount);

  /** 
   This method is triggered when you can perform some updates.
   The frequency varries by the test executor that you choose
   */
  void update();

  /// This method is trigered when your tests are ended 
  void end(SuiteResult[]);
}

/// A listener that provides test cases to be executed
interface ITestDiscovery {
  TestCase[] getTestCases();
}

/** 
A Listener that can run tests. During the test execution can be used only one 
instance of this listance. After all the tests were executed the result of all
three methods are concatenated and passed to `ILifecycleListener.end(SuiteResult[])`
*/
interface ITestExecutor
{
  /// Called before all tests were discovered and they are ready to be executed
  SuiteResult[] beginExecution(ref const(TestCase)[]);

  /// Run a particullary test case
  SuiteResult[] execute(ref const(TestCase));

  /// Called when there is no more test to be executed
  SuiteResult[] endExecution();
}

/// A Listener for the suite events
interface ISuiteLifecycleListener
{
  /// Called before a suite execution
  void begin(ref SuiteResult);

  /// Called after a suite execution
  void end(ref SuiteResult);
}

/// A Listener for the test case events
interface ITestCaseLifecycleListener
{
  /// Called before a test execution
  void begin(string suite, ref TestResult);

  // Called after a test execution
  void end(string suite, ref TestResult);
}

/// A Listener for the step events
interface IStepLifecycleListener
{
  /// Called before a step begins
  void begin(string suite, string test, ref StepResult);

  /// Called after a step ended
  void end(string suite, string test, ref StepResult);
}

/// A test case that will be executed
struct TestCase
{
  /** 
  The test case suite name. It can contain `.` which is treated as a 
  separator for nested suites
  */
  string suiteName;

  /// The test name
  string name;

  /**
   The function that must be executed to check if the test passes or not.
   In case of failure, an exception is thrown.
  */
  TestCaseFunction func;

  /**
    A list of labels that will be added to the final report
  */
  string[string] labels;

  ///
  this(const TestCase testCase) {
    suiteName = testCase.suiteName.dup;
    name = testCase.name.dup;
    func = testCase.func;

    foreach(key, val; testCase.labels) {
      labels[key] = val;
    }
  }

  ///
  this(string suiteName, string name, TestCaseFunction func) {
    this.suiteName = suiteName;
    this.name = name;
    this.func = func;
  }

  ///
  this(string suiteName, string name, TestCaseFunction func, string[string] labels) {
    this.suiteName = suiteName;
    this.name = name;
    this.func = func;
    this.labels = labels;
  }
}

///
TestResult toTestResult(const TestCase testCase) {
  auto testResult = new TestResult(testCase.name.dup);

  testResult.begin = Clock.currTime;
  testResult.end = testResult.begin;

  foreach(key, label; testCase.labels) {
    testResult.labels[key] = label;
  }

  return testResult;
}

/// A suite result
struct SuiteResult
{
  /**
  The suite name. It can contain `.` which is treated as a 
  separator for nested suites
  */
  string name;

  /// when the suite started
  SysTime begin;

  /// when the suite ended
  SysTime end;

  /// the tests executed for the current suite
  TestResult[] tests;

  ///
  @disable
  this();

  ///
  this(string name) {
    this.name = name;
    begin = SysTime.fromUnixTime(0);
    end = SysTime.fromUnixTime(0);
  }

  ///
  this(string name, SysTime begin, SysTime end) {
    this.name = name;
    this.begin = begin;
    this.end = end;
  }

  ///
  this(string name, SysTime begin, SysTime end, TestResult[] tests) {
    this.name = name;
    this.begin = begin;
    this.end = end;
    this.tests = tests;
  }
}

/// A step result
class StepResult
{
  /// The step name
  string name;

  /// when the step started
  SysTime begin;

  /// when the step ended
  SysTime end;

  /// the list of the child steps
  StepResult[] steps;

  this() {
    begin = SysTime.min;
    end = SysTime.min;
  }
}

/// A test result
class TestResult : StepResult
{
  /// The states that a test can have.
  enum Status
  {
    ///
    created,
    ///
    failure,
    ///
    skip,
    ///
    started,
    ///
    success,
    ///
    unknown
  }

  /// Represents the test status
  Status status = Status.created;

  /**
    A list of labels that will be added to the final report
  */
  string[string] labels;

  /**
   The reason why a test has failed. This value must be set only if the tests has the
   `failure` state
   */
  Throwable throwable;

  /// Convenience constructor that sets the test name
  this(string name)
  {
    this.name = name;
    super();
  }
}

version (unittest)
{
  import std.stdio;
  import std.conv;
  import std.algorithm;
  import core.thread;

  import trial.step;
  import trial.runner;
  import fluent.asserts;
  import trial.executor.single;

  __gshared bool executed;

  void mock() @system
  {
    executed = true;
  }

  void failureMock() @system
  {
    executed = true;
    assert(false);
  }

  void stepFunction(int i)
  {
    Step("Step " ~ i.to!string);
  }

  void stepMock() @system
  {
    auto a = Step("some step");
    executed = true;

    for (int i; i < 3; i++)
    {
      stepFunction(i);
    }
  }
}

/// Convert a test case to test result
unittest {
  auto testCase = TestCase("Suite name", "test name", &stepMock, [ "label": "value" ]);
  auto testResult = testCase.toTestResult;

  testResult.name.should.equal("test name");
  testResult.labels.keys.should.equal(["label"]);
  testResult.labels["label"].should.equal("value");
  testResult.begin.should.be.greaterThan(Clock.currTime - 1.seconds);
  testResult.end.should.be.greaterThan(Clock.currTime - 1.seconds);
  testResult.status.should.equal(TestResult.Status.created);
}

@("A suite runner should run a success test case and add it to the result")
unittest
{
  TestCase[] tests = [TestCase("Suite name1", "someTestCase", &mock)];

  executed = false;

  auto old = LifeCycleListeners.instance;
  scope (exit)
    LifeCycleListeners.instance = old;

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);

  auto begin = Clock.currTime - 1.msecs;
  auto result = tests.runTests;
  auto end = Clock.currTime + 1.msecs;

  result.length.should.equal(1);
  result[0].tests.length.should.equal(1);
  result[0].tests[0].begin.should.be.between(begin, end);
  result[0].tests[0].end.should.be.between(begin, end);
  result[0].tests[0].status.should.be.equal(TestResult.Status.success);
  executed.should.equal(true);
}

@("A suite runner should run a failing test case and add it to the result")
unittest
{
  TestCase[] tests = [TestCase("Suite name2", "someTestCase", &failureMock)];

  executed = false;
  auto old = LifeCycleListeners.instance;
  scope (exit)
    LifeCycleListeners.instance = old;

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);

  auto begin = Clock.currTime - 1.msecs;
  auto result = tests.runTests;
  auto end = Clock.currTime + 1.msecs;

  result.length.should.equal(1);
  result[0].tests.length.should.equal(1);
  result[0].tests[0].begin.should.be.between(begin, end);
  result[0].tests[0].end.should.be.between(begin, end);
  result[0].tests[0].status.should.be.equal(TestResult.Status.failure);

  executed.should.equal(true);
}

@("A suite runner should call the suite lifecycle listener methods")
unittest
{
  auto old = LifeCycleListeners.instance;
  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);
  scope (exit)
    LifeCycleListeners.instance = old;

  auto beginTime = Clock.currTime - 1.msecs;
  TestCase[] tests = [TestCase("Suite name", "someTestCase", &mock)];

  string[] order = [];
  class TestSuiteListener : ISuiteLifecycleListener, ITestCaseLifecycleListener
  {
    void begin(ref SuiteResult suite)
    {
      suite.name.should.equal("Suite name");
      suite.begin.should.be.greaterThan(beginTime);
      suite.end.should.be.greaterThan(beginTime);

      suite.tests.length.should.equal(0);

      order ~= "beginSuite";
    }

    void end(ref SuiteResult suite)
    {
      suite.name.should.equal("Suite name");
      suite.begin.should.be.greaterThan(beginTime);
      suite.end.should.be.greaterThan(beginTime);
      suite.tests[0].status.should.equal(TestResult.Status.success);

      order ~= "endSuite";
    }

    void begin(string suite, ref TestResult test)
    {
      test.name.should.equal("someTestCase");
      test.begin.should.be.greaterThan(beginTime);
      test.end.should.be.greaterThan(beginTime);
      test.status.should.equal(TestResult.Status.started);

      order ~= "beginTest";
    }

    void end(string suite, ref TestResult test)
    {
      test.name.should.equal("someTestCase");
      test.begin.should.be.greaterThan(beginTime);
      test.end.should.be.greaterThan(beginTime);
      test.status.should.equal(TestResult.Status.success);

      order ~= "endTest";
    }
  }

  LifeCycleListeners.instance.add(new TestSuiteListener);

  tests.runTests;

  order.should.equal(["beginSuite", "beginTest", "endTest", "endSuite"]);
}

@("A test runner should add the steps to the report")
unittest
{
  auto beginTime = Clock.currTime - 1.msecs;
  auto const test = TestCase("Suite name", "someTestCase", &stepMock);

  auto old = LifeCycleListeners.instance;
  scope (exit)
  {
    LifeCycleListeners.instance = old;
  }

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);

  auto result = [ test ].runTests;

  result[0].tests[0].steps.length.should.equal(1);
  result[0].tests[0].steps[0].name.should.equal("some step");
  result[0].tests[0].steps[0].begin.should.be.greaterThan(beginTime);
  result[0].tests[0].steps[0].end.should.be.greaterThan(beginTime);

  result[0].tests[0].steps[0].steps.length.should.equal(3);
  result[0].tests[0].steps[0].steps.each!(step => step.name.should.startWith("Step "));
}

@("A test runner should call the test listeners in the right order")
unittest
{
  auto const test = TestCase("Suite name", "someTestCase", &stepMock);
  string[] order = [];

  class StepListener : IStepLifecycleListener
  {
    void begin(string suite, string test, ref StepResult step)
    {
      order ~= "begin " ~ step.name;
    }

    void end(string suite, string test, ref StepResult step)
    {
      order ~= "end " ~ step.name;
    }
  }

  auto old = LifeCycleListeners.instance;
  scope (exit)
    LifeCycleListeners.instance = old;

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);
  LifeCycleListeners.instance.add(new StepListener);

  auto result = [test].runTests;

  order.should.equal(["begin some step", "begin Step 0", "end Step 0",
      "begin Step 1", "end Step 1", "begin Step 2", "end Step 2", "end some step"]);
}

@("A suite runner should set the data to an empty suite runner")
unittest
{
  TestCase[] tests;
  auto old = LifeCycleListeners.instance;
  scope (exit)
    LifeCycleListeners.instance = old;

  LifeCycleListeners.instance = new LifeCycleListeners;
  LifeCycleListeners.instance.add(new DefaultExecutor);

  auto begin = Clock.currTime - 1.msecs;
  auto result = tests.runTests();
  auto end = Clock.currTime + 1.msecs;

  result.length.should.equal(0);
}

/// Attribute that marks the test as flaky. Different reporters will interpret this information
/// in different ways.
struct Flaky {

  /// Returns the labels that set the test a flaky
  static string[string] labels() {
    return ["status_details": "flaky"];
  }
}