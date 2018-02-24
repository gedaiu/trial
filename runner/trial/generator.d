module trial.generator;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.exception;

import dub.internal.vibecompat.core.log;

import trial.settings;

private string[string] templates;

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

    foreach(m; modules) {
      code ~= `      testDiscovery` ~ index.to!string ~ `.addModule!(` ~ "`" ~ m[0] ~ "`" ~ `, ` ~ "`" ~ m[1] ~ "`" ~ `);` ~ "\n";
    }

    code ~= "\n      LifeCycleListeners.instance.add(testDiscovery" ~ index.to!string ~ ");\n\n";
    index++;
  }

  return code;
}

void setupTemplate(string file)() {
  mixin("templates[`" ~ file ~"`] = import(`" ~ file ~ "`);");
}

string generateTestFile(Settings settings, bool hasTrialDependency, string[2][] modules, string[] externalModules) {
  setupTemplate!"templates/coverage.css";
  setupTemplate!"templates/coverage.svg";
  setupTemplate!"templates/coverageBody.html";
  setupTemplate!"templates/coverageColumn.html";
  setupTemplate!"templates/coverageHeader.html";
  setupTemplate!"templates/indexTable.html";
  setupTemplate!"templates/ignoredTable.html";
  setupTemplate!"templates/page.html";
  setupTemplate!"templates/progress.html";
  setupTemplate!"templates/htmlReporter.html";

  setupTemplate!"assets/trial.css";
  setupTemplate!"assets/trial.js";

  enum d =
    import("reporters/writer.d") ~
    import("reporters/result.d") ~
    import("reporters/stats.d") ~
    import("reporters/dotmatrix.d") ~
    import("reporters/html.d") ~
    import("reporters/allure.d") ~
    import("reporters/landing.d") ~
    import("reporters/list.d") ~
    import("reporters/progress.d") ~
    import("reporters/specprogress.d") ~
    import("reporters/specsteps.d") ~
    import("reporters/spec.d") ~
    import("reporters/xunit.d") ~
    import("reporters/tap.d") ~
    import("reporters/visualtrial.d") ~

    import("runner.d") ~
    import("interfaces.d") ~
    import("executor/parallel.d") ~
    import("executor/single.d") ~
    import("discovery/unit.d") ~
    import("discovery/code.d") ~
    import("discovery/spec.d") ~
    import("discovery/testclass.d") ~
    import("settings.d") ~
    import("step.d") ~
    import("coverage.d") ~
    import("attributes.d") ~
    import("terminal.d") ~
    import("stackresult.d");

  string code;

  if(hasTrialDependency) {
    code = "
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
  } else {
    logInfo("We will embed the `trial:lifecycle` code inside the project.");

    code = "version = is_trial_embeded;\n" ~ d.split("\n")
            .filter!(a => !a.startsWith("module"))
            .filter!(a => !a.startsWith("@(\""))
            .filter!(a => a.indexOf("import") == -1 || a.indexOf("trial.") == -1)
            .join("\n")
            .removeUnittests
            .replaceImports;
  }

  code ~= `
  int main(string[] arguments) {
      setupLifecycle(` ~ settings.toCode ~ `);` ~ "\n\n";

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
        return runTests(arguments).isSuccess ? 0 : 1;
      }
  }

  version (unittest) shared static this()
  {
      import core.runtime;
      Runtime.moduleUnitTester = () => true;
  }`;

  return code;
}

version(unittest) {
  import std.datetime;
  import fluent.asserts;
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

string replaceImports(string source) {
  auto pieces = source.split(`import("`);

  foreach(i; 1..pieces.length) {
    auto tmpPieces = pieces[i].split(`")`);
    auto path = tmpPieces[0];

    enforce(path in templates, "`" ~ path ~ "` was not found in the template cache");
    pieces[i] = "`" ~ templates[path] ~ "`" ~ tmpPieces[1..$].join(`")`);
  }

  return pieces.join("");
}

/// It should replace the import statement with the file content
unittest {
  templates["templates/something.html"] = "content";
  `string toLineCoverage(T)(LineCoverage line, T index) {
  return import("templates/something.html")
            .replaceVariable("hasCode", line.hasCode ? "has-code" : "")
            .replaceVariable("hit", line.hits > 0 ? "hit" : "")
            .replaceVariable("line", index.to!string)
  `.replaceImports.should.equal(`string toLineCoverage(T)(LineCoverage line, T index) {
  return ` ~ "`content`" ~ `
            .replaceVariable("hasCode", line.hasCode ? "has-code" : "")
            .replaceVariable("hit", line.hits > 0 ? "hit" : "")
            .replaceVariable("line", index.to!string)
  `);
}