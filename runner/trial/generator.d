module trial.generator;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.digest.sha;
import std.exception;

import dub.internal.vibecompat.core.log;

import trial.discovery.unit;
import trial.settings;

///
string generateDiscoveries(string[] discoveries, string[2][] modules) {
  string code;

  uint index;
  foreach(discovery; discoveries) {
    string[] pieces = discovery.split(".");
    string cls = pieces[pieces.length - 1];

    if(pieces[0] != "trial") {
      code ~= "\n    import " ~ pieces[0..$-1].join(".") ~ ";\n";
    }

    code ~= "      auto testDiscovery" ~ index.to!string ~ " = new " ~ cls ~ ";\n";

    if(discovery == "trial.discovery.unit.UnitTestDiscovery") {
      code ~= `static if(__traits(hasMember, UnitTestDiscovery, "comments")) {`;
      foreach(m; modules) {
        code ~= `      UnitTestDiscovery.comments["` ~ m[0] ~ `"] = [` ~ m[0].readText.compressComments.map!"a.toCode".join(",\n            ").array.to!string ~ `];` ~ "\n";
      }
      code ~= "}";
    }

    foreach(m; modules) {
      code ~= `      testDiscovery` ~ index.to!string ~ `.addModule!(` ~ "`" ~ m[0] ~ "`" ~ `, ` ~ "`" ~ m[1] ~ "`" ~ `);` ~ "\n";
    }

    code ~= "\n      LifeCycleListeners.instance.add(testDiscovery" ~ index.to!string ~ ");\n\n";
    index++;
  }

  return code;
}

string generateTestFile(Settings settings, bool hasTrialDependency, string[2][] modules, string[] externalModules) {

  string code = "
      import std.getopt;
      import std.string;
      import trial.discovery.unit;
      import trial.discovery.spec;
      import trial.discovery.testclass;
      import trial.runner;
      import trial.interfaces;
      import trial.settings;
      import trial.stackresult;
      import trial.reporters.result;
      import trial.reporters.stats;
      import trial.reporters.spec;
      import trial.reporters.specsteps;
      import trial.reporters.dotmatrix;
      import trial.reporters.landing;
      import trial.reporters.progress;
      import trial.reporters.xunit;
      import trial.reporters.tap;
      import trial.reporters.visualtrial;
      import trial.reporters.result;\n";

  code ~= settings.plugins
    .map!(a => a.toLower.replace("-", ""))
    .map!(a => a.toLower.replace(":", "."))
    .map!(a => "      import " ~ a ~ ".plugin;")
    .join("\n");

  code ~= `
  int main(string[] arguments) {
      string testName;
      string suiteName;
      string executor;
      string reporters;

      getopt(
        arguments,
        "testName|t",  &testName,
        "suiteName|s", &suiteName,
        "executor|e",  &executor,
        "reporters|r", &reporters
      );

      auto settings = ` ~ settings.toCode ~ `;

      static if(__traits(hasMember, Settings, "executor")) {
        if(executor != "") {
          settings.executor = executor;
        }
      }

      if(reporters != "") {
        settings.reporters = reporters.split(",");
      }

      setupLifecycle(settings);` ~ "\n\n";

  if(hasTrialDependency) {
    externalModules ~= [ "_d_assert", "std.", "core." ];

    code~= `
      StackResult.externalModules = ` ~ externalModules.to!string ~ `;
    `;
  }

  code ~= generateDiscoveries(settings.testDiscovery, modules);

  code ~= `
      if(arguments.length > 1 && arguments[1] == "describe") {
        import std.stdio;
        describeTests.toJSONHierarchy.write;
        return 0;
      } else {
        return runTests(LifeCycleListeners.instance.getTestCases, testName, suiteName).isSuccess ? 0 : 1;
      }
  }

  version (unittest) shared static this()
  {
      import core.runtime;
      Runtime.moduleUnitTester = () => true;
  }`;

  return code;
}

void writeTrialFolder(string destination) {
  enum paths = [
    "assets/trial.css",
    "assets/trial.js",

    "templates/coverage.css",
    "templates/coverage.svg",
    "templates/coverageBody.html",
    "templates/coverageColumn.html",
    "templates/coverageHeader.html",
    "templates/htmlReporter.html",
    "templates/ignoredTable.html",
    "templates/indexTable.html",
    "templates/page.html",
    "templates/progress.html",

    "trial/attributes.d",
    "trial/coverage.d",
    "trial/interfaces.d",
    "trial/runner.d",
    "trial/settings.d",
    "trial/stackresult.d",
    "trial/step.d",
    "trial/terminal.d",

    "trial/discovery/code.d",
    "trial/discovery/spec.d",
    "trial/discovery/testclass.d",
    "trial/discovery/unit.d",

    "trial/executor/parallel.d",
    "trial/executor/process.d",
    "trial/executor/single.d",

    "trial/reporters/allure.d",
    "trial/reporters/dotmatrix.d",
    "trial/reporters/html.d",
    "trial/reporters/landing.d",
    "trial/reporters/list.d",
    "trial/reporters/progress.d",
    "trial/reporters/result.d",
    "trial/reporters/spec.d",
    "trial/reporters/specprogress.d",
    "trial/reporters/specsteps.d",
    "trial/reporters/stats.d",
    "trial/reporters/tap.d",
    "trial/reporters/visualtrial.d",
    "trial/reporters/writer.d",
    "trial/reporters/xunit.d"
  ];

  static foreach(path; paths) {{
    string content = import(path)
      .removeUnittests
      .split("\n")
      .filter!(a => !a.strip.startsWith("@(\""))
      .filter!(a => !a.strip.startsWith("@Flaky"))
      .filter!(a => !a.strip.startsWith("@Issue"))
      .join("\n");

    auto fileDestination = buildPath(destination, path);
    auto parent = fileDestination.dirName;

    if(!parent.exists) {
      mkdirRecurse(parent);
    }

    if(!fileDestination.exists || getFileHash(fileDestination) != getStringHash(content)) {
      std.file.write(fileDestination, content);
    }
  }}
}

string getStringHash(const string content) pure {
  ubyte[28] hash = sha224Of(content);

  return toHexString(hash).idup;
}

string getFileHash(string fileName) {
  return getStringHash(std.file.readText(fileName));
}

string removeTest(string data) {
  auto cnt = 0;

  if(data[0] == ')') {
    return "unittest" ~ data;
  }

  if(data[0] != '{') {
    return data;
  }

  char ignore;

  foreach(size_t i, ch; data) {
    if(ignore != char.init) {

      if(ignore == ch) {
        ignore = char.init;
      }

      continue;
    }

    if(ch == '`') {
      ignore = '`';
    }

    if(ch == '"') {
      ignore = '"';
    }

    if(ch == '{') {
      cnt++;
    }

    if(ch == '}') {
      cnt--;
    }

    if(cnt == 0) {
      return data[i+1..$];
    }
  }

  return data;
}

string removeUnittests(string data) {
  import trial.discovery.code;

  auto pieces = data.split("unittest");

  auto tokens = stringToDTokens(data);
  auto iterator = TokenIterator(tokens);

  string cleanContent;

  foreach(token; iterator) {
    string type = str(token.type);

    if(type == "comment") {
      continue;
    }

    if(type == "unittest") {
      iterator.skipNextBlock;
      continue;
    }

    if(type == "version") {
      iterator.skipUntilType("(");
      string value = iterator.currentToken.text == "" ? str(iterator.currentToken.type) : iterator.currentToken.text;

      if(value == "whitespace") {
        iterator.skipWsAndComments;
      } else {
        iterator.skipOne;
      }

      value = iterator.currentToken.text == "" ? str(iterator.currentToken.type) : iterator.currentToken.text;

      if(value == "unittest") {
        iterator.skipNextBlock;
      } else {
        cleanContent ~= `version(` ~ value ~ `)`;
        iterator.skipUntilType(")");
      }

      continue;
    }

    cleanContent ~= token.text == "" && type != "stringLiteral" ? type : token.text;
  }

  return cleanContent;
}