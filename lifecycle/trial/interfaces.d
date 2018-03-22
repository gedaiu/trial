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
import std.file;
import std.path;
import std.uuid;
import std.exception;
import std.json;
import std.algorithm;

version (Have_fluent_asserts) {
  version = Have_fluent_asserts_core;
}

version(unittest) {
  version(Have_fluent_asserts_core) {
    import fluent.asserts;
  }
}

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

  fields ~= `"file":"` ~ throwable.file.escapeJson ~ `",`;
  fields ~= `"line":"` ~ throwable.line.to!string.escapeJson ~ `",`;
  fields ~= `"msg":"` ~ throwable.msg.escapeJson ~ `",`;
  fields ~= `"info":"` ~ throwable.info.to!string.escapeJson ~ `",`;
  fields ~= `"raw":"` ~ throwable.toString.escapeJson ~ `"`;

  return "{" ~ fields ~ "}";
}

/// convert a Throwable to json
unittest {
  auto exception = new Exception("some message", __FILE__, 58);
  exception.toJsonString.should.equal(`{"file":"lifecycle/trial/interfaces.d","line":"58","msg":"some message","info":"null","raw":"object.Exception@lifecycle/trial/interfaces.d(58): some message"}`);
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

  ///
  static Label[] fromJsonArray(string value) {
    return parseJSON(value).array.map!(a => Label(a["name"].str, a["value"].str)).array;
  }

  ///
  static Label fromJson(string value) {
    auto parsedValue = parseJSON(value);

    return Label(parsedValue["name"].str, parsedValue["value"].str);
  }
}

/// Label string representation should be in Json format
unittest {
  Label("name", "value").toString.should.equal(`{ "name": "name", "value": "value" }`);
}

/// create a label from a json object
unittest {
  auto label = Label.fromJson(`{ "name": "name", "value": "value" }`);

  label.name.should.equal("name");
  label.value.should.equal("value");
}

/// create a label list from a json array
unittest {
  auto labels = Label.fromJsonArray(`[{ "name": "name1", "value": "value1" }, { "name": "name2", "value": "value2" }]`);

  labels.should.equal([ Label("name1", "value1"), Label("name2", "value2") ]);
}

/// A struct representing an attachment for test steps
struct Attachment {
  /// The attachment name
  string name;

  /// The absolute path to the attachment
  string file;

  /// The file mime path
  string mime;

  /// The attachement destination. All the attached files will be copied in this folder if 
  /// it is not allready inside
  static string destination;

  /// Add a file to the current test or step
  static Attachment fromFile(const string name, const string path, const string mime) {
    auto fileDestination = buildPath(destination, randomUUID.toString ~ "." ~ path.baseName);
    copy(path, fileDestination);

    auto a = const Attachment(name, fileDestination, mime);

    if(LifeCycleListeners.instance !is null) {
      LifeCycleListeners.instance.attach(a);
    }

    return a;
  }

  string toString() inout {
    string fields;
    fields ~= `"name":"` ~ name ~ `",`;
    fields ~= `"file":"` ~ file ~ `",`;
    fields ~= `"mime":"` ~ mime ~ `"`;

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
  this(string name, SysTime begin) {
    this.name = name;
    this.begin = begin;
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
  auto attachment = Attachment.fromFile("readme file", "README.md", "text/plain");

  attachment.file.exists.should.equal(true);
}

/// An exception that should be thrown by the pending test cases
class PendingTestException : Exception {

  ///
  this(string file = __FILE__, size_t line = __LINE__, Throwable next = null)  {
    super("You cannot run pending tests", file, line, next);
  }
}

/// The lifecycle listeners collections. You must use this instance in order
/// to extend the runner. You can have as many listeners as you want. The only restriction
/// is for ITestExecutor, which has no sense to have more than one instance for a run
class LifeCycleListeners {

  /// The global instange.
  static LifeCycleListeners instance;

  private {
    ISuiteLifecycleListener[] suiteListeners;
    ITestCaseLifecycleListener[] testListeners;
    IStepLifecycleListener[] stepListeners;
    ILifecycleListener[] lifecycleListeners;
    ITestDiscovery[] testDiscoveryListeners;
    IAttachmentListener[] attachmentListeners;
    ITestExecutor executor;

    string currentTest;
    bool started;
  }

  @property {
    /// Return an unique name for the current running test. If there is no test running it
    /// will return an empty string
    string runningTest() const nothrow {
      return currentTest;
    }

    /// True if the tests are being executed
    bool isRunning() {
      return started;
    }
  }

  ///
  TestCase[] getTestCases() {
    return testDiscoveryListeners.map!(a => a.getTestCases).join;
  }

  /// Add a listener to the collection
  void add(T)(T listener) {
    static if(!is(CommonType!(ISuiteLifecycleListener, T) == void)) {
      suiteListeners ~= cast(ISuiteLifecycleListener) listener;
      suiteListeners = suiteListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(ITestCaseLifecycleListener, T) == void)) {
      testListeners ~= cast(ITestCaseLifecycleListener) listener;
      testListeners = testListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(IStepLifecycleListener, T) == void)) {
      stepListeners ~= cast(IStepLifecycleListener) listener;
      stepListeners = stepListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(ILifecycleListener, T) == void)) {
      lifecycleListeners ~= cast(ILifecycleListener) listener;
      lifecycleListeners = lifecycleListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(ITestExecutor, T) == void)) {
      if(cast(ITestExecutor) listener !is null) {
        executor = cast(ITestExecutor) listener;
      }
    }

    static if(!is(CommonType!(ITestDiscovery, T) == void)) {
      testDiscoveryListeners ~= cast(ITestDiscovery) listener;
      testDiscoveryListeners = testDiscoveryListeners.filter!(a => a !is null).array;
    }

    static if(!is(CommonType!(IAttachmentListener, T) == void)) {
      attachmentListeners ~= cast(IAttachmentListener) listener;
      attachmentListeners = attachmentListeners.filter!(a => a !is null).array;
    }
  }

  /// Send the attachment to all listeners
  void attach(ref const Attachment attachment) {
    attachmentListeners.each!(a => a.attach(attachment));
  }

  /// Send the update event to all listeners
  void update() {
    lifecycleListeners.each!"a.update";
  }

  /// Send the begin run event to all listeners
  void begin(ulong testCount) {
    lifecycleListeners.each!(a => a.begin(testCount));
  }

  /// Send the end runer event to all listeners
  void end(SuiteResult[] result) {
    lifecycleListeners.each!(a => a.end(result));
  }

  /// Send the begin suite event to all listeners
  void begin(ref SuiteResult suite) {
    suiteListeners.each!(a => a.begin(suite));
  }

  /// Send the end suite event to all listeners
  void end(ref SuiteResult suite) {
    suiteListeners.each!(a => a.end(suite));
  }

  /// Send the begin test event to all listeners
  void begin(string suite, ref TestResult test) {
    currentTest = suite ~ "." ~ test.name;
    testListeners.each!(a => a.begin(suite, test));
  }

  /// Send the end test event to all listeners
  void end(string suite, ref TestResult test) {
    currentTest = "";
    testListeners.each!(a => a.end(suite, test));
  }

  /// Send the begin step event to all listeners
  void begin(string suite, string test, ref StepResult step) {
    currentTest = suite ~ "." ~ test ~ "." ~ step.name;
    stepListeners.each!(a => a.begin(suite, test, step));
  }

  /// Send the end step event to all listeners
  void end(string suite, string test, ref StepResult step) {
    currentTest = "";
    stepListeners.each!(a => a.end(suite, test, step));
  }

  /// Send the execute test to the executor listener
  SuiteResult[] execute(ref const(TestCase) func) {
    started = true;
    scope(exit) started = false;
    return executor.execute(func);
  }

  /// Send the begin execution with the test case list to the executor listener
  SuiteResult[] beginExecution(ref const(TestCase)[] tests) {
    enforce(executor !is null, "The test executor was not set.");
    return executor.beginExecution(tests);
  }

  /// Send the end execution the executor listener
  SuiteResult[] endExecution() {
    return executor.endExecution();
  }
}
