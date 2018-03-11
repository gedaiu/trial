module tests.trial.executors.process;

import std.datetime;

import trial.executors.process;
import trial.discovery.spec;

import fluent.asserts;

private string[] testHistory;

void mockProcessExecutor(string suite, string testName) {
  testHistory ~= suite ~ ":" ~ testName;
}

void pendingTest() {
  throw new PendingTestException();
}

alias s = Spec!({
  describe("The process executor", {
    ProcessExecutor executor;

    beforeEach({
      testHistory = [];
      executor = new ProcessExecutor(&mockProcessExecutor);
    });

    it("should call the process executor for a test", {
      auto testCase = const TestCase("Some.Suite", "test name", &pendingTest, []);

      executor.execute(testCase);

      testHistory.should.equal(["Some.Suite:test name"]);
    });

    it("should return a suite result for a test case", {
      auto testCase = const TestCase("Some.Suite", "test name", &pendingTest, []);
      auto begin = Clock.currTime;

      auto result = executor.execute(testCase);
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

      auto result = executor.execute(testCase)[0].tests[0];

      result.begin.should.be.greaterThan(begin);
      result.end.should.be.greaterThan(begin);
      result.name.should.equal("test name");
      result.status.should.equal(TestResult.Status.success);
      result.fileName.should.endWith(__FILE__);
      result.line.should.equal(50);
    });
  });
});