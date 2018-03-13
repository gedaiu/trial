module tests.trial.executors.process;

import std.datetime;

import trial.executor.process;
import trial.discovery.spec;
import trial.reporters.visualtrial;

import fluent.asserts;

private string[] testHistory;

void mockProcessExecutor(string suite, string testName, VisualTrialReporterParser parser) {
  testHistory ~= suite ~ ":" ~ testName;
  parser.testResult.status = TestResult.Status.success;
}

void pendingTest() {
  throw new PendingTestException();
}

alias s = Spec!({
  describe("The process executor", {
    ProcessExecutor executor;
    LifeCycleListeners listeners;

    beforeEach({
      testHistory = [];
      executor = new ProcessExecutor(&mockProcessExecutor);
      listeners = LifeCycleListeners.instance;
      LifeCycleListeners.instance = new LifeCycleListeners();
      LifeCycleListeners.instance.add(executor);
    });

    afterEach({
      LifeCycleListeners.instance = listeners;
    });

    after({
      LifeCycleListeners.instance = listeners;
    });

    it("should call the process executor for a test", {
      auto testCase = const TestCase("Some.Suite", "test name", &pendingTest, []);

      executor.execute(testCase);

      testHistory.should.equal(["Some.Suite:test name"]);
    });

    it("should return a suite result for a test case", {
      auto testCase = const TestCase("Some.Suite", "test name", &pendingTest, []);
      auto begin = Clock.currTime;
      
      executor.execute(testCase);
      auto result = executor.endExecution;
      result.length.should.equal(1);

      result[0].begin.should.be.greaterThan(begin);
      result[0].end.should.be.greaterThan(begin);
      result[0].name.should.equal("Some.Suite");
      result[0].tests.length.should.equal(1);
    });

    it("should return a test result for a test case", {
      auto location = SourceLocation(__FILE_FULL_PATH__, 50);
      auto testCase = const TestCase("Some.Suite", "test name", &pendingTest, [], location);

      auto begin = Clock.currTime;
      executor.execute(testCase);

      auto result = executor.endExecution[0].tests[0];

      result.begin.should.be.greaterThan(begin);
      result.end.should.be.greaterThan(begin);
      result.name.should.equal("test name");
      result.status.should.equal(TestResult.Status.success);
      result.fileName.should.endWith(__FILE__);
      result.line.should.equal(50);
    });

    it("should return a suite result for two test cases with the same suite", {
      auto testCase1 = const TestCase("Some.Suite", "test name 1", &pendingTest, []);
      auto testCase2 = const TestCase("Some.Suite", "test name 2", &pendingTest, []);
      auto begin = Clock.currTime;
      
      auto result = executor.execute(testCase1);
      result.length.should.equal(0);

      result = executor.execute(testCase2);
      result.length.should.equal(0);

      result = executor.endExecution;
      result.length.should.equal(1);

      result[0].begin.should.be.greaterThan(begin);
      result[0].end.should.be.greaterThan(begin);
      result[0].name.should.equal("Some.Suite");
      result[0].tests.length.should.equal(2);
      result[0].tests[0].name.should.equal("test name 1");
      result[0].tests[1].name.should.equal("test name 2");
    });
  });
});