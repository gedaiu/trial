module trial.coverage;

import std.algorithm;
import std.range;
import std.string;
import std.stdio;
import std.conv;
import std.exception;
import std.file;
import std.path;

import trial.discovery.code;

shared static this() {
  import core.runtime;

  if(!exists("coverage/raw")) {
    mkdirRecurse("coverage/raw");
  }

  dmd_coverDestPath("coverage/raw");
}

/// Converts coverage lst files to html
void convertLstFiles(string packagePath) {
  if(!exists("coverage/html")) {
    mkdirRecurse("coverage/html");
  }

  std.file.write(buildPath("coverage", "html", "coverage.css"), import("coverage.css"));

  auto coverageData =
    dirEntries("coverage/raw", SpanMode.shallow)
    .filter!(f => f.name.endsWith(".lst"))
    .filter!(f => f.isFile)
    .map!(a => readText(a.name))
    .map!(a => a.toCoverageFile(packagePath));

  foreach (data; coverageData) {
    auto htmlFile = data.path.replace("/", "-").replace("\\", "-") ~ ".html";
    std.file.write(buildPath("coverage", "html", htmlFile), data.toHtml);
  }
}

/// Get the line that contains the coverage summary
auto getCoverageSummary(string fileContent) {
  auto lines = fileContent.splitLines.array;

  std.algorithm.reverse(lines);

  return lines
      .filter!(a => a.indexOf('|') == -1 || a.indexOf('|') > 9)
      .map!(a => a.strip)
      .filter!(a => a != "");
}

/// It should get the coverage summary from the .lst file with no coverage
unittest {
  "
       |  double threadUsage(uint index);
       |}
  core/cloud/source/cloud/system.d has no code
  ".getCoverageSummary.front.should.equal("core/cloud/source/cloud/system.d has no code");
}

/// It should get the coverage summary from the .lst file with missing data
unittest {
  "

  ".getCoverageSummary.empty.should.equal(true);
}

/// It should get the coverage summary from the .lst file with percentage
unittest {
  "
      2|  statusList[0].properties[\"thread1\"].value.should.startWith(\"1;\");
       |}
  core/cloud/source/cloud/system.d is 88% covered
  ".getCoverageSummary.front.should.equal("core/cloud/source/cloud/system.d is 88% covered");
}

/// Get the filename from the coverage summary
string getFileName(string fileContent) {
  auto r = fileContent.getCoverageSummary;

  if(r.empty) {
    return "";
  }

  auto pos = r.front.lastIndexOf(".d");

  return r.front[0..pos + 2];
}

version(unittest) {
  import fluent.asserts;
}

/// It should get the filename from the .lst file with no coverage
unittest {
  "
       |  double threadUsage(uint index);
       |}
  core/cloud/source/cloud/system.d has no code
  ".getFileName.should.equal("core/cloud/source/cloud/system.d");
}

/// It should get the filename from the .lst file with no code
unittest {
  "


  ".getFileName.should.equal("");
}

/// It should get the filename from the .lst file with percentage
unittest {
  "
      2|  statusList[0].properties[\"thread1\"].value.should.startWith(\"1;\");
       |}
  core/cloud/source/cloud/system.d is 88% covered
  ".getFileName.should.equal("core/cloud/source/cloud/system.d");
}

/// Get the percentage from the covered summary
double getCoveragePercent(string fileContent) {
  auto r = fileContent.getCoverageSummary;

  if(r.empty) {
    return 100;
  }

  auto pos = r.front.lastIndexOf('%');

  if(pos == -1) {
    return 100;
  }

  auto pos2 = r.front[0..pos].lastIndexOf(' ') + 1;

  return r.front[pos2..pos].to!double;
}

/// It should get the filename from the .lst file with no coverage
unittest {
  "
       |  double threadUsage(uint index);
       |}
  core/cloud/source/cloud/system.d has no code
  ".getCoveragePercent.should.equal(100);
}

/// It should get the filename from the .lst file with no code
unittest {
  "


  ".getCoveragePercent.should.equal(100);
}

/// It should get the filename from the .lst file with percentage
unittest {
  "
      2|  statusList[0].properties[\"thread1\"].value.should.startWith(\"1;\");
       |}
  core/cloud/source/cloud/system.d is 88% covered
  ".getCoveragePercent.should.equal(88);
}

/// The representation of a line from the .lst file
struct LineCoverage {

  ///
  string code;

  ///
  size_t hits;

  ///
  bool hasCode;

  @disable this();

  ///
  this(string line) {
    enforce(line.indexOf("\n") == -1, "You should provide a line");
    line = line.strip;
    auto column = line.indexOf("|");

    if(column == -1) {
      code = line;
    } else if(column == 0) {
      code = line[1..$];
    } else {
      hits = line[0..column].strip.to!size_t;
      hasCode = true;
      code = line[column + 1..$];
    }
  }
}

/// It should parse an empty line
unittest
{
  auto lineCoverage = LineCoverage(`      |`);
  lineCoverage.code.should.equal("");
  lineCoverage.hits.should.equal(0);
  lineCoverage.hasCode.should.equal(false);
}

/// Parse the file lines
auto toCoverageLines(string fileContent) {
  return fileContent
      .splitLines
      .filter!(a => a.indexOf('|') != -1 && a.indexOf('|') < 10)
      .map!(a => a.strip)
      .map!(a => LineCoverage(a));
}

/// It should convert a .lst file to covered line structs
unittest {
  auto lines =
"      |
       |import std.stdio;
     75|  this(File f) {
       |  }
core/cloud/source/cloud/system.d is 88% covered
".toCoverageLines.array;

  lines.length.should.equal(4);

  lines[0].code.should.equal("");
  lines[0].hits.should.equal(0);
  lines[0].hasCode.should.equal(false);

  lines[1].code.should.equal("import std.stdio;");
  lines[1].hits.should.equal(0);
  lines[1].hasCode.should.equal(false);

  lines[2].code.should.equal("  this(File f) {");
  lines[2].hits.should.equal(75);
  lines[2].hasCode.should.equal(true);

  lines[3].code.should.equal("  }");
  lines[3].hits.should.equal(0);
  lines[3].hasCode.should.equal(false);
}

/// Structure that represents one .lst file
struct CoveredFile {
  /// The covered file path
  string path;

  /// Is true if the file is from the tested library and
  /// false if is an external file
  bool isInCurrentProject;

  /// The module name
  string moduleName;

  /// The covered percent
  double coveragePercent;

  /// The file lines with coverage data
  LineCoverage[] lines;
}

/// Converts a .lst file content to a CoveredFile structure
CoveredFile toCoverageFile(string content, string packagePath) {

  auto fileName = content.getFileName;
  auto fullPath = buildNormalizedPath(getcwd, fileName);

  return CoveredFile(
    fileName,
    fullPath.indexOf(packagePath) == 0,
    getModuleName(fullPath),
    getCoveragePercent(content),
    content.toCoverageLines.array);
}

/// should convert a .lst file to CoveredFile structure
unittest {
  auto result = `       |/++
       |  The main runner logic. You can find here some LifeCycle logic and test runner
       |  initalization
       |+/
       |module trial.runner;
       |
       |  /// Send the begin run event to all listeners
       |  void begin(ulong testCount) {
     23|    lifecycleListeners.each!(a => a.begin(testCount));
       |  }
lifecycle/trial/runner.d is 74% covered
`.toCoverageFile(buildPath(getcwd, "lifecycle/trial"));

  result.path.should.equal("lifecycle/trial/runner.d");
  result.isInCurrentProject.should.equal(true);
  result.moduleName.should.equal("trial.runner");
  result.coveragePercent.should.equal(74);
  result.lines.length.should.equal(10);
  result.lines[0].code.should.equal("/++");
  result.lines[9].code.should.equal("  }");
}

/// Generate the html for a line coverage
string toLineCoverage(T)(LineCoverage line, T index) {
  return `<div class="line ` ~ 
            (line.hasCode ? "has-code" : "") ~ ` ` ~ 
            (line.hits > 0 ? "hit" : "") ~ `"><span class="line-number">` ~ 
              index.to!string ~ `</span><span class="hit-count">` ~ line.hits.to!string ~ `</span></div>`;
}

/// Get the line coverage column for the html report
string toHtmlCoverage(LineCoverage[] lines) {
  return lines.enumerate(1).map!(a => a[1].toLineCoverage(a[0])).array.join("");
}

/// Cont how many lines were hit
auto hitLines(LineCoverage[] lines) {
  return lines.filter!(a => a.hits > 0).array.length;
}

/// Cont how many lines were hit
auto codeLines(LineCoverage[] lines) {
  return lines.filter!(a => a.hasCode).array.length;
}

string toHtml(CoveredFile coveredFile) {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">

  <link rel="stylesheet" href="http://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css">
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
  <link rel="stylesheet" href="coverage.css">

  <script src="http://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js"></script>
  <script src="http://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/languages/d.min.js"></script>
  <title>` ~ coveredFile.moduleName ~ ` Coverage</title>
</head>
<body>
  <header>
    <h1>` ~ coveredFile.moduleName ~ ` - ` ~ coveredFile.path ~ `</h1>
    
    Lines ` ~ coveredFile.lines.hitLines.to!string ~ `/` ~ coveredFile.lines.codeLines.to!string ~ `
    <div class="progress">
      <div class="progress-bar progress-bar-info progress-bar-striped" role="progressbar" aria-valuenow="` ~ coveredFile.coveragePercent.to!string ~ `" aria-valuemin="0" aria-valuemax="100" style="width: ` ~ coveredFile.coveragePercent.to!string ~ `%">
        <span class="sr-only">` ~ coveredFile.coveragePercent.to!string ~ `% Covered</span>
        ` ~ coveredFile.coveragePercent.to!string ~ `%
      </div>
    </div>
  
  </header>
  <main class="coverage">
    <figure>
      <pre class="code-container">
        <div class="coverage-container">` ~ coveredFile.lines.toHtmlCoverage ~ `</div>
        <code class="d">` ~ coveredFile.lines.map!(a => a.code.replace("<", "&lt;").replace(">", "&gt;")).array.join("\n") ~ `</code>
      </pre>
    </figure>
  </main>
  <script>hljs.initHighlightingOnLoad();</script>
</body>
</html>`;
}
