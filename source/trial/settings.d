/++
  Settings parser and structures

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.settings;

import trial.reporters.result;
import trial.reporters.spec;
import trial.reporters.specsteps;
import trial.reporters.dotmatrix;
import trial.reporters.landing;
import trial.reporters.progress;

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
  string[] reporters = ["spec", "result"];

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
