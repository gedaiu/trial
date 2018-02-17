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
import std.functional;
import std.conv;

/// Alias to a Test Case function type
alias TestCaseDelegate = void delegate() @system;
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

/// Convert a Throwable to a json string
string toJsonString(Throwable throwable) {
  if(throwable is null) {
    return "{}";
  }

  string fields;

  fields ~= `"file":"` ~ throwable.file ~ `",`;
  fields ~= `"line":"` ~ throwable.line.to!string ~ `",`;
  fields ~= `"msg":"` ~ throwable.msg ~ `",`;
  fields ~= `"info":"` ~ throwable.info.to!string ~ `",`;
  fields ~= `"raw":"` ~ throwable.toString ~ `"`;

  return "{" ~ fields ~ "}";
}

/// convert a Throwable to json
unittest {
  auto exception = new Exception("some message");
  exception.toJsonString.should.equal(`{"file":"lifecycle/trial/interfaces.d","line":"55","msg":"some message","info":"null","raw":"object.Exception@lifecycle/trial/interfaces.d(55): some message"}`);
}


/// A listener that provides test cases to be executed
interface ITestDiscovery {
  /// Get the test cases from the compiled source code
  TestCase[] getTestCases();
}

/// A listener that provides test cases contained in a certain file
interface ITestDescribe {
  /// Get the test cases by parsing the source code
  TestCase[] discoverTestCases(string file);
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

/// A Listener for handling attachments
interface IAttachmentListener
{
  /// Called when an attachment is ready
  void attach(ref const Attachment);
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

/// A struct representing a label for test results
struct Label {
  /// The label name
  string name;

  /// The label value
  string value;

  /// Convert the struct to a JSON string
  string toString() inout {
    return `{ "name": "` ~ name.escapeJson ~ `", "value": "` ~ value.escapeJson ~ `" }`;
  }
}

/// Label string representation should be in Json format
unittest {
  Label("name", "value").toString.should.equal(`{ "name": "name", "value": "value" }`);
}

/// A struct representing an attachment for test steps
struct Attachment {
  /// The attachment name
  string name;

  /// The absolute path to the attachment
  string file;

  /// The file mime path
  string mime;

  /// Add a file to the current test or step
  static void fromFile(const string name, const string path, const string mime) {
    import trial.runner;

    auto a = const Attachment(name, path, name);

    if(LifeCycleListeners.instance !is null) {
      LifeCycleListeners.instance.attach(a);
    }
  }

  string toString() inout {
    string fields;
    fields ~= `"name":"`~name~`",`;
    fields ~= `"file":"`~file~`",`;
    fields ~= `"mime":"`~mime~`"`;

    return "{" ~ fields ~ "}";
  }
}

/// Convert an attachement to Json string
unittest {

  Attachment("dub", "dub.json", "text/json").toString.should.equal(
    `{"name":"dub","file":"dub.json","mime":"text/json"}`
  );
}

/// Represents a line of code in a certain file.
struct SourceLocation {
  ///
  string fileName;

  ///
  size_t line;

  /// Converts the structure to a JSON string
  string toString() inout {
    return `{ "fileName": "` ~ fileName.escapeJson ~ `", "line": ` ~ line.to!string ~ ` }`;
  }
}


/// SourceLocation string representation should be a JSON string
unittest {
  SourceLocation("file.d", 10).toString.should.equal(`{ "fileName": "file.d", "line": 10 }`);
}

private string escapeJson(string value) {
  return value.replace(`"`, `\"`).replace("\r", `\r`).replace("\n", `\n`).replace("\t", `\t`);
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
  TestCaseDelegate func;

  /**
    A list of labels that will be added to the final report
  */
  Label[] labels;

  /// The test location
  SourceLocation location;

  ///
  this(const TestCase testCase) {
    suiteName = testCase.suiteName.dup;
    name = testCase.name.dup;
    func = testCase.func;
    location = testCase.location;
    labels.length = testCase.labels.length;

    foreach(key, val; testCase.labels) {
      labels[key] = val;
    }
  }

  ///
  this(T)(string suiteName, string name, T func, Label[] labels, SourceLocation location) {
    this(suiteName, name, func.toDelegate, labels);
    this.location = location;
  }

  ///
  this(string suiteName, string name, TestCaseFunction func, Label[] labels = []) {
    this(suiteName, name, func.toDelegate, labels);
  }

  ///
  this(string suiteName, string name, TestCaseDelegate func, Label[] labels = []) {
    this.suiteName = suiteName;
    this.name = name;
    this.func = func;
    this.labels = labels;
  }

  string toString() const {
    string jsonRepresentation = "{ ";

    jsonRepresentation ~= `"suiteName": "` ~ suiteName.escapeJson ~ `", `;
    jsonRepresentation ~= `"name": "` ~ name.escapeJson ~ `", `;
    jsonRepresentation ~= `"labels": [ ` ~ labels.map!(a => a.toString).join(", ") ~ ` ], `;
    jsonRepresentation ~= `"location": ` ~ location.toString;

    return jsonRepresentation ~ " }";
  }
}

/// TestCase string representation should be a JSON string
unittest {
  void MockTest() {}

  auto testCase = TestCase("some suite", "some name", &MockTest, [ Label("label1", "value1"), Label("label2", "value2") ]);
  testCase.location = SourceLocation("file.d", 42);

  testCase.toString.should.equal(`{ "suiteName": "some suite", "name": "some name", ` ~
    `"labels": [ { "name": "label1", "value": "value1" }, { "name": "label2", "value": "value2" } ], ` ~
    `"location": { "fileName": "file.d", "line": 42 } }`);
}

///
TestResult toTestResult(const TestCase testCase) {
  auto testResult = new TestResult(testCase.name.dup);

  testResult.begin = Clock.currTime;
  testResult.end = testResult.begin;
  testResult.labels = testCase.labels.dup;
  testResult.fileName = testCase.location.fileName;
  testResult.line = testCase.location.line;

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

  /// The list of attached files
  Attachment[] attachments;

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

  ///
  this(string name, SysTime begin, SysTime end, TestResult[] tests, Attachment[] attachments) {
    this.name = name;
    this.begin = begin;
    this.end = end;
    this.tests = tests;
    this.attachments = attachments;
  }

  /// Convert the struct to a json string
  string toString() {
    string fields;
    fields ~= `"name":"` ~ name.escapeJson ~ `",`;
    fields ~= `"begin":"` ~ begin.toISOExtString ~ `",`;
    fields ~= `"end":"` ~ end.toISOExtString ~ `",`;
    fields ~= `"tests":[` ~ tests.map!(a => a.toString).join(",") ~ `],`;
    fields ~= `"attachments":[` ~ attachments.map!(a => a.toString).join(",") ~ `]`;

    return "{" ~ fields ~ "}";
  }
}

unittest {
  auto result = SuiteResult("suite name",
    SysTime.fromISOExtString("2000-01-01T00:00:00Z"),
    SysTime.fromISOExtString("2000-01-01T01:00:00Z"),
    [ new TestResult("test name") ],
    [ Attachment() ]);

  result.toString.should.equal(
    `{"name":"suite name","begin":"2000-01-01T00:00:00Z","end":"2000-01-01T01:00:00Z","tests":[{"name":"test name","begin":"-29227-04-19T21:11:54.5224192Z","end":"-29227-04-19T21:11:54.5224192Z","steps":[],"attachments":[],"fileName":"","line":"0","status":"created","labels":[],"throwable":{}}],"attachments":[{"name":"","file":"","mime":""}]}`
  );
}

/// A step result
class StepResult
{
  /// The step name
  string name;

  /// When the step started
  SysTime begin;

  /// When the step ended
  SysTime end;

  /// The list of the child steps
  StepResult[] steps;

  /// The list of attached files
  Attachment[] attachments;

  this() {
    begin = SysTime.min;
    end = SysTime.min;
  }

  protected string fields() {
    string result;
    
    result ~= `"name":"` ~ name.escapeJson ~ `",`;
    result ~= `"begin":"` ~ begin.toISOExtString ~ `",`;
    result ~= `"end":"` ~ end.toISOExtString ~ `",`;
    result ~= `"steps":[` ~ steps.map!(a => a.toString).join(",") ~ `],`;
    result ~= `"attachments":[` ~ attachments.map!(a => a.toString).join(",") ~ `]`;

    return result;
  }

  /// Convert the result to a json string
  override string toString() {
    return "{" ~ fields ~ "}";
  }
}

/// Convert a step result to a json
unittest {
  auto step = new StepResult();
  step.name = "step name";
  step.begin = SysTime.fromISOExtString("2000-01-01T00:00:00Z");
  step.end = SysTime.fromISOExtString("2000-01-01T01:00:00Z");
  step.steps = [ new StepResult() ];
  step.attachments = [ Attachment() ];

  step.toString.should.equal(`{"name":"step name","begin":"2000-01-01T00:00:00Z","end":"2000-01-01T01:00:00Z","steps":` ~
  `[{"name":"","begin":"-29227-04-19T21:11:54.5224192Z","end":"-29227-04-19T21:11:54.5224192Z","steps":[],"attachments":`~
  `[]}],"attachments":[{"name":"","file":"","mime":""}]}`);
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
    pending,
    ///
    unknown
  }

  /// The file that contains this test
  string fileName;

  /// The line where this test starts
  size_t line;

  /// Represents the test status
  Status status = Status.created;

  /**
    A list of labels that will be added to the final report
  */
  Label[] labels;

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

  /// Convert the result to a json string
  override string toString() {
    string result = fields ~ ",";

    result ~= `"fileName":"` ~ fileName.escapeJson ~ `",`;
    result ~= `"line":"` ~ line.to!string ~ `",`;
    result ~= `"status":"` ~ status.to!string ~ `",`;
    result ~= `"labels":[` ~ labels.map!(a => a.toString).join(",") ~ `],`;
    result ~= `"throwable":` ~ throwable.toJsonString;

    return "{" ~ result ~ "}";
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
  auto testCase = TestCase("Suite name", "test name", &stepMock, [ Label("label", "value") ]);
  auto testResult = testCase.toTestResult;

  testResult.name.should.equal("test name");
  testResult.labels.should.equal([ Label("label", "value") ]);
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

  auto result = tests.runTests();

  result.length.should.equal(0);
}

/// Attribute that marks the test as flaky. Different reporters will interpret this information
/// in different ways.
struct Flaky {

  /// Returns the labels that set the test a flaky
  static Label[] labels() {
    return [Label("status_details", "flaky")];
  }
}

/// Attribute that links an issue to a test. Some test reporters can display links, so the value can be also
/// a link.
struct Issue {

  private string name;

  /// Returns the labels that set the issue label
  Label[] labels() {
    return [ Label("issue", name) ];
  }
}

/// Attribute that sets the feaure label
struct Feature {
  private string name;

  /// Returns the labels that set the feature label
  Label[] labels() {
    return [ Label("feature", name) ];
  }
}

/// Attribute that sets the story label
struct Story {
  private string name;

  /// Returns the labels that set the feature label
  Label[] labels() {
    return [ Label("story", name) ];
  }
}

/// Attach the readme file
unittest {
  Attachment.fromFile("readme file", "README.md", "text/plain");
}

/// An exception that should be thrown by the pending test cases
class PendingTestException : Exception {

  ///
  this(string file = __FILE__, size_t line = __LINE__, Throwable next = null)  {
    super("You cannot run pending tests", file, line, next);
  }
}