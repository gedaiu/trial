/++
  The main runner logic. You can find here some LifeCycle logic and test runner
  initalization

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.runner;

import std.stdio;
import std.algorithm;
import std.datetime;
import std.range;
import std.traits;
import std.string;
import std.conv;
import std.path;
import std.getopt;
import std.file;
import std.path;
import std.exception;

import trial.settings;
import trial.executor.single;
import trial.executor.parallel;
import trial.executor.process;

static this() {
  if(LifeCycleListeners.instance is null) {
    LifeCycleListeners.instance = new LifeCycleListeners;
  }
}

/// setup the LifeCycle collection
void setupLifecycle(Settings settings) {
  settings.artifactsLocation = settings.artifactsLocation.asAbsolutePath.array;

  Attachment.destination = buildPath(settings.artifactsLocation, "attachment");
  
  if(!Attachment.destination.exists) {
    Attachment.destination.mkdirRecurse;
  }

  if(LifeCycleListeners.instance is null) {
    LifeCycleListeners.instance = new LifeCycleListeners;
  }

  settings.reporters.map!(a => a.toLower).each!(a => addReporter(a, settings));

  addExecutor(settings.executor, settings);
}

void addExecutor(string name, Settings settings) {
  switch(name) {
      case "default":
        LifeCycleListeners.instance.add(new DefaultExecutor);
        break;
      case "parallel":
        LifeCycleListeners.instance.add(new ParallelExecutor(settings.maxThreads));
        break;
      case "process":
        LifeCycleListeners.instance.add(new ProcessExecutor());
        break;
      
      default:
        if(name != "") {
          writeln("There is no `" ~ name ~ "` executor. Using the default.");
        }

        LifeCycleListeners.instance.add(new DefaultExecutor);
  }
}

/// Adds an embeded reporter listener to the LifeCycle listeners collection
void addReporter(string name, Settings settings) {
    import trial.reporters.spec;
    import trial.reporters.specprogress;
    import trial.reporters.specsteps;
    import trial.reporters.dotmatrix;
    import trial.reporters.landing;
    import trial.reporters.progress;
    import trial.reporters.list;
    import trial.reporters.html;
    import trial.reporters.allure;
    import trial.reporters.stats;
    import trial.reporters.result;
    import trial.reporters.xunit;
    import trial.reporters.tap;
    import trial.reporters.visualtrial;

    switch(name) {
      case "spec":
        LifeCycleListeners.instance.add(new SpecReporter(settings));
        break;

      case "spec-progress":
        auto storage = statsFromFile(buildPath(settings.artifactsLocation, "stats.csv"));
        LifeCycleListeners.instance.add(new SpecProgressReporter(storage));
        break;

      case "spec-steps":
        LifeCycleListeners.instance.add(new SpecStepsReporter(settings));
        break;

      case "dot-matrix":
        LifeCycleListeners.instance.add(new DotMatrixReporter(settings.glyphs.dotMatrix));
        break;

      case "landing":
        LifeCycleListeners.instance.add(new LandingReporter(settings.glyphs.landing));
        break;

      case "list":
        LifeCycleListeners.instance.add(new ListReporter(settings));
        break;

      case "progress":
        LifeCycleListeners.instance.add(new ProgressReporter(settings.glyphs.progress));
        break;

      case "html":
        LifeCycleListeners.instance.add(
          new HtmlReporter(buildPath(settings.artifactsLocation, "result.html"), 
          settings.warningTestDuration, 
          settings.dangerTestDuration));
        break;

      case "allure":
        LifeCycleListeners.instance.add(new AllureReporter(buildPath(settings.artifactsLocation, "allure")));
        break;

      case "xunit":
        LifeCycleListeners.instance.add(new XUnitReporter(buildPath(settings.artifactsLocation, "xunit")));
        break;

      case "result":
        LifeCycleListeners.instance.add(new ResultReporter(settings.glyphs.result));
        break;

      case "stats":
        LifeCycleListeners.instance.add(new StatsReporter(buildPath(settings.artifactsLocation, "stats.csv")));
        break;

      case "tap":
        LifeCycleListeners.instance.add(new TapReporter);
        break;

      case "visualtrial":
        LifeCycleListeners.instance.add(new VisualTrialReporter);
        break;

      default:
        writeln("There is no `" ~ name ~ "` reporter");
    }
}

/// Returns an associative array of the detected tests,
/// where the key is the suite name and the value is the TestCase
const(TestCase)[][string] describeTests() {
  return describeTests(LifeCycleListeners.instance.getTestCases);
}

/// Returns an associative array of the detected tests,
/// where the key is the suite name and the value is the TestCase
const(TestCase)[][string] describeTests(const(TestCase)[] tests) {
  const(TestCase)[][string] groupedTests;

  foreach(test; tests) {
    groupedTests[test.suiteName] ~= test;
  }

  return groupedTests;
}

///
string toJSONHierarchy(T)(const(T)[][string] items) {
  struct Node {
    Node[string] nodes;
    const(T)[] values;

    void add(string[] path, const(T)[] values) {
      if(path.length == 0) {
        this.values = values;
        return;
      }

      if(path[0] !in nodes) {
        nodes[path[0]] = Node();
      }

      nodes[path[0]].add(path[1..$], values);
    }

    string toString(int spaces = 2) {
      string prefix = leftJustify("", spaces);
      string endPrefix = leftJustify("", spaces - 2);
      string listValues = "";
      string objectValues = "";

      if(values.length > 0) {
        listValues = values
          .map!(a => a.toString)
          .map!(a => prefix ~ a)
          .join(",\n");
      }

      if(nodes.keys.length > 0) {
        objectValues = nodes
              .byKeyValue
              .map!(a => `"` ~ a.key ~ `": ` ~ a.value.toString(spaces + 2))
              .map!(a => prefix ~ a)
              .join(",\n");
      }


      if(listValues != "" && objectValues != "") {
        return "{\n" ~ objectValues ~ ",\n" ~ prefix ~ "\"\": [\n" ~ listValues ~ "\n" ~ prefix ~ "]\n" ~ endPrefix ~ "}";
      }

      if(listValues != "") {
        return "[\n" ~ listValues ~ "\n" ~ endPrefix ~ "]";
      }

      return "{\n" ~ objectValues ~ "\n" ~ endPrefix ~ "}";
    }
  }

  Node root;

  foreach(key; items.keys) {
    root.add(key.split("."), items[key]);
  }

  return root.toString;
}

/// convert an assoc array to JSON hierarchy
unittest {
  struct Mock {
    string val;

    string toString() inout {
      return `"` ~ val ~ `"`;
    }
  }

  const(Mock)[][string] mocks;

  mocks["a.b"] = [ Mock("val1"), Mock("val2") ];
  mocks["a.c"] = [ Mock("val3") ];

  mocks.toJSONHierarchy.should.equal(`{
  "a": {
    "b": [
      "val1",
      "val2"
    ],
    "c": [
      "val3"
    ]
  }
}`);
}

/// it should have an empty key for items that contain both values and childs
unittest {
  struct Mock {
    string val;

    string toString() inout {
      return `"` ~ val ~ `"`;
    }
  }

  const(Mock)[][string] mocks;

  mocks["a.b"] = [ Mock("val1"), Mock("val2") ];
  mocks["a.b.c"] = [ Mock("val3") ];

  mocks.toJSONHierarchy.should.equal(`{
  "a": {
    "b": {
      "c": [
        "val3"
      ],
      "": [
      "val1",
      "val2"
      ]
    }
  }
}`);
}

/// describeTests should return the tests cases serialised in json format
unittest {
  void TestMock() @system { }

  TestCase[] tests;
  tests ~= TestCase("a.b", "some test", &TestMock, [ Label("some label", "label value") ]);
  tests ~= TestCase("a.c", "other test", &TestMock);

  auto result = describeTests(tests);

  result.values.length.should.equal(2);
  result.keys.should.containOnly([ "a.b", "a.c" ]);
  result["a.b"].length.should.equal(1);
  result["a.c"].length.should.equal(1);
}

/// Runs the tests and returns the results
auto runTests(const(TestCase)[] tests, string testName = "", string suiteName = "") {
  setupSegmentationHandler!true();

  const(TestCase)[] filteredTests = tests;

  if(testName != "") {
    filteredTests = tests.filter!(a => a.name.indexOf(testName) != -1).array;
  }

  if(suiteName != "") {
    filteredTests = filteredTests.filter!(a => a.suiteName.indexOf(suiteName) != -1).array;
  }

  LifeCycleListeners.instance.begin(filteredTests.length);

  SuiteResult[] results = LifeCycleListeners.instance.beginExecution(filteredTests);

  foreach(test; filteredTests) {
    results ~= LifeCycleListeners.instance.execute(test);
  }

  results ~= LifeCycleListeners.instance.endExecution;
  LifeCycleListeners.instance.end(results);

  return results;
}

/// Check if a suite result list is a success
bool isSuccess(SuiteResult[] results) {
  return results.map!(a => a.tests).joiner.map!(a => a.status).all!(a => a == TestResult.Status.success || a == TestResult.Status.pending);
}

version(unittest) {
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
}

/// It should return true for an empty result
unittest {
  [].isSuccess.should.equal(true);
}

/// It should return true if all the tests succeded
unittest {
  SuiteResult[] results = [ SuiteResult("") ];
  results[0].tests = [ new TestResult("") ];
  results[0].tests[0].status = TestResult.Status.success;

  results.isSuccess.should.equal(true);
}

/// It should return false if one the tests failed
unittest {
  SuiteResult[] results = [ SuiteResult("") ];
  results[0].tests = [ new TestResult("") ];
  results[0].tests[0].status = TestResult.Status.failure;

  results.isSuccess.should.equal(false);
}

/// It should return the name of this test
unittest {
  if(LifeCycleListeners.instance is null || !LifeCycleListeners.instance.isRunning) {
    return;
  }

  LifeCycleListeners.instance.runningTest.should.equal("trial.runner.It should return the name of this test");
}

void setupSegmentationHandler(bool testRunner)()
{
  import core.runtime;

  // backtrace
  version(CRuntime_Glibc)
    import core.sys.linux.execinfo;
  else version(OSX)
    import core.sys.darwin.execinfo;
  else version(FreeBSD)
    import core.sys.freebsd.execinfo;
  else version(NetBSD)
    import core.sys.netbsd.execinfo;
  else version(Windows)
    import core.sys.windows.stacktrace;
  else version(Solaris)
    import core.sys.solaris.execinfo;

  static if( __traits( compiles, backtrace ) )
  {
    version(Posix) {
      import core.sys.posix.signal; // segv handler

      static extern (C) void unittestSegvHandler(int signum, siginfo_t* info, void* ptr ) nothrow
      {
        import core.stdc.stdio;

        core.stdc.stdio.printf("\n\n");

        static if(testRunner) {
          if(signum == SIGSEGV) {
            core.stdc.stdio.printf("Got a Segmentation Fault running ");
          }

          if(signum == SIGBUS) {
            core.stdc.stdio.printf("Got a bus error running ");
          }


          if(LifeCycleListeners.instance.runningTest != "") {
            core.stdc.stdio.printf("%s\n\n", LifeCycleListeners.instance.runningTest.ptr);
          } else {
            core.stdc.stdio.printf("some setup step. This is probably a Trial bug. Please create an issue on github.\n\n");
          }
        } else {
          if(signum == SIGSEGV) {
            core.stdc.stdio.printf("Got a Segmentation Fault! ");
          }

          if(signum == SIGBUS) {
            core.stdc.stdio.printf("Got a bus error! ");
          }

          core.stdc.stdio.printf(" This is probably a Trial bug. Please create an issue on github.\n\n");
        }

        static enum MAXFRAMES = 128;
        void*[MAXFRAMES]  callstack;
        int               numframes;

        numframes = backtrace( callstack.ptr, MAXFRAMES );
        backtrace_symbols_fd( callstack.ptr, numframes, 2);
      }

      sigaction_t action = void;
      (cast(byte*) &action)[0 .. action.sizeof] = 0;
      sigfillset( &action.sa_mask ); // block other signals
      action.sa_flags = SA_SIGINFO | SA_RESETHAND;
      action.sa_sigaction = &unittestSegvHandler;
      sigaction( SIGSEGV, &action, null );
      sigaction( SIGBUS, &action, null );
    }
  }
}