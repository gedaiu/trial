module trial.runnersettings;

import std.path;
import std.file;

import vibe.data.json;

import dub.commandline;

import trial.settings;
import trial.jsonvalidation;

class RunnerSettings {
  Settings settings;

  bool combined;
  bool parallel;
  bool force;

  string reporters;
  string executor;
  string plugins;

  string testName;
  string suiteName;

  string buildType = "unittest";

  this() {
    string path = "trial.json";

    if (!path.exists) {
      Settings def;
      Json serializedSettings = def.serializeToJson;
      serializedSettings.remove("glyphs");

      std.file.write(path, serializedSettings.toPrettyString);
    }

    Json jsonSettings;

    try {
      jsonSettings = readText(path).parseJsonString;
    } catch (JSONException) {
      throw new Exception("The Json from `" ~ path ~ "` is invalid.");
    }

    validateJson!Settings(jsonSettings,"", " in `" ~ path ~ "`");

    settings = readText(path).deserializeJson!Settings;
  }

  auto applyArguments(CommandArgs args) {
    args.getopt("combined", &this.combined,
      ["Tries to build the whole project in a single compiler run."]);

    args.getopt("parallel", &this.parallel,
      ["Runs multiple compiler instances in parallel, if possible."]);

    args.getopt("f|force", &this.force,
      ["Forces a recompilation even if the target is up to date."]);

    args.getopt("t|test", &this.testName,
      ["It will run all the tests that contain this text in the name."]);

    args.getopt("s|suite", &this.suiteName,
      ["It will run all the suites that contain this text in the name."]);

    args.getopt("r|reporters", &this.settings.reporters,
      ["Override the reporters from the `trial.json` file. eg. -r spec,result,stats"]);

    args.getopt("e|executor", &this.settings.executor,
      ["Override the test executor"]);

    args.getopt("p|plugins", &this.settings.plugins,
      ["Add a trial plugin as dependency from code.dlang.org. eg. -p trial-plugin1,trial-plugin2"]);

    bool coverage = false;
    args.getopt("coverage", &coverage,
      ["Enables code coverage statistics to be generated."]);

    if (coverage) {
      buildType = "unittest-cov";
    }
  }
}
