/++
  Settings parser and structures

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.settings;
import std.conv;

import trial.reporters.result;
import trial.reporters.spec;
import trial.reporters.specsteps;
import trial.reporters.dotmatrix;
import trial.reporters.landing;
import trial.reporters.progress;

version(Have_dub) {
  import dub.internal.vibecompat.data.serialization;
}
///
mixin template SettingsFields()
{
  /*
  bool colors;
  bool sort;
  bool bail;*/

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

  /// The test discovery classes that you want to use
  string[] testDiscovery = ["trial.discovery.unit.UnitTestDiscovery"];

  /// The default executor is `SingleRunner`. If you want to use the
  /// `ParallelExecutor` set this flag true.
  bool runInParallel = false;

  /// The number of threads tha you want to use
  /// `0` means the number of cores that your processor has
  uint maxThreads = 0;

  ///
  GlyphSettings glyphs;

  string artifactsLocation = ".trial";
}

/// A structure representing the `trial.json` file
struct Settings
{
  version(Have_dub) {
    @optional {
      mixin SettingsFields;
    }
  } else {
    mixin SettingsFields;
  }
}

mixin template GlyphSettingsFields()
{
  ///
  SpecGlyphs spec;

  ///
  SpecStepsGlyphs specSteps;

  ///
  ResultGlyphs result;

  ///
  DotMatrixGlyphs dotMatrix;

  ///
  LandingGlyphs landing;

  ///
  ProgressGlyphs progress;
}

/// The gliph settings
struct GlyphSettings {
  version(Have_dub) {
    @optional {
      mixin GlyphSettingsFields;
    }
  } else {
    mixin GlyphSettingsFields;
  }
}

/// Converts the settings object to DLang code. It's used by the generator
string toCode(Settings settings)
{
  return "Settings(" ~
    settings.reporters.to!string ~ ", " ~
    settings.testDiscovery.to!string ~ ", " ~
    settings.runInParallel.to!string ~ ", " ~
    settings.maxThreads.to!string ~ ", " ~
    settings.glyphs.toCode ~ ", " ~
    `"` ~ settings.artifactsLocation ~ `"` ~
    ")";
}

/// Converts the GlyphSettings object to DLang code. It's used by the generator
string toCode(GlyphSettings settings) {
  return "GlyphSettings(" ~
      specGlyphsToCode(settings.spec) ~ ", " ~
      specStepsGlyphsToCode(settings.specSteps) ~ ", " ~
      resultGlyphsToCode(settings.result) ~ ", " ~
      dotMatrixGlyphsToCode(settings.dotMatrix) ~ ", " ~
      landingGlyphsToCode(settings.landing) ~ ", " ~
      progressGlyphsToCode(settings.progress) ~
    ")";
}

version (unittest)
{
	import fluent.asserts;
}

/// it should be able to compile the settings code
unittest {
  mixin("auto settings = " ~ Settings().toCode ~ ";");
}

/// it should be able to transform  the Settings to code.
unittest
{
	Settings settings;

	settings.toCode.should.equal(`Settings(` ~
     `["spec", "result"], ` ~
     `["trial.discovery.unit.UnitTestDiscovery"], false, 0, ` ~
      "GlyphSettings(SpecGlyphs(`✓`), " ~
                    "SpecStepsGlyphs(`┌`, `└`, `│`), "~
                    "ResultGlyphs(`✖`), " ~
                    "DotMatrixGlyphs(`.`,`!`,`?`), " ~
                    "LandingGlyphs(`✈`,`━`,`⋅`), " ~
                    "ProgressGlyphs(`░`,`▓`)" ~
      "), " ~
      `".trial"` ~
      `)`);
}
