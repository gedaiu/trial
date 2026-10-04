/++
  Settings parser and structures

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.settings;

import std.json : JSONValue, parseJSON;

import trial.reporters.result;
import trial.reporters.spec;
import trial.reporters.specsteps;
import trial.reporters.dotmatrix;
import trial.reporters.landing;
import trial.reporters.progress;

version (unittest) {
  version (Have_fluent_asserts) {
    import fluent.asserts;
  }
}

/// A structure representing the `trial.json` file
struct Settings
{
  /** The reporter list that will be added by the runner at startup
   * You can use here only the embeded reporters.
   * If you want to use a custom reporter you can use `static this` constructor
   *
   * Examples:
   * ------------------------
   * static this
   * {
   *    LifeCycleListeners.instance.add(myCustomReporter);
   * }
   * ------------------------
   */
  string[] reporters = ["spec", "result", "stats", "html", "allure", "xunit"];

  /// The number of threads tha you want to use
  /// `0` means the number of cores that your processor has
  uint maxThreads = 0;

  ///
  GlyphSettings glyphs;

  /// Where to generate artifacts
  string artifactsLocation = ".trial";

  /// Show the duration with yellow if it takes more `warningTestDuration` msecs
  uint warningTestDuration = 20;

  /// Show the duration with red if it takes more `dangerTestDuration` msecs
  uint dangerTestDuration = 100;

  /// The default executor is `SingleRunner`. If you want to use the
  /// `ParallelExecutor` set this option to `parallel` or if you want
  /// to use the `ProcessExecutor` set it to `process`.
  string executor = "default";
}

/// Settings has the spec, result, stats, html, allure and xunit reporters by default
unittest {
  Settings().reporters.should.equal(["spec", "result", "stats", "html", "allure", "xunit"]);
}

/// The gliph settings
struct GlyphSettings {
  ///
  SpecGlyphs spec;

  ///
  SpecStepsGlyphs specSteps;

  ///
  TestResultGlyphs result;

  ///
  DotMatrixGlyphs dotMatrix;

  ///
  LandingGlyphs landing;

  ///
  ProgressGlyphs progress;
}

/// Converts a json value to a `string[]`, `string` or `uint` setting field
T fromJson(T)(JSONValue value) {
  import std.algorithm : map;
  import std.array : array;

  static if (is(T == string[])) {
    return value.array.map!(item => item.str).array;
  } else static if (is(T == string)) {
    return value.str;
  } else {
    return value.get!T;
  }
}

/// fromJson returns ["tap", "xunit"] for a json string array
unittest {
  fromJson!(string[])(parseJSON(`["tap", "xunit"]`)).should.equal(["tap", "xunit"]);
}

/// fromJson returns "parallel" for a json string
unittest {
  fromJson!string(parseJSON(`"parallel"`)).should.equal("parallel");
}

/// fromJson returns 4 for a json integer read as uint
unittest {
  fromJson!uint(parseJSON(`4`)).should.equal(4u);
}

/// Parses the content of a `trial.json` file into `Settings`
Settings toSettings(string json) {
  auto parsed = parseJSON(json);
  Settings settings;

  static foreach (key; ["reporters", "executor", "maxThreads", "artifactsLocation", "warningTestDuration", "dangerTestDuration"]) {
    if (auto value = key in parsed) {
      alias Field = typeof(__traits(getMember, Settings, key));
      __traits(getMember, settings, key) = fromJson!Field(*value);
    }
  }

  return settings;
}

/// toSettings returns the default settings for an empty object
unittest {
  toSettings("{}").should.equal(Settings());
}

/// toSettings returns the reporters ["tap", "xunit"] from the reporters key
unittest {
  toSettings(`{"reporters": ["tap", "xunit"]}`).reporters.should.equal(["tap", "xunit"]);
}

/// toSettings returns the executor "parallel" from the executor key
unittest {
  toSettings(`{"executor": "parallel"}`).executor.should.equal("parallel");
}

/// toSettings returns the maxThreads 4 from the maxThreads key
unittest {
  toSettings(`{"maxThreads": 4}`).maxThreads.should.equal(4u);
}

/// toSettings returns artifactsLocation "out", warningTestDuration 5 and dangerTestDuration 50 from their keys
unittest {
  Settings expected;
  expected.artifactsLocation = "out";
  expected.warningTestDuration = 5;
  expected.dangerTestDuration = 50;

  toSettings(`{"artifactsLocation": "out", "warningTestDuration": 5, "dangerTestDuration": 50}`).should.equal(expected);
}
