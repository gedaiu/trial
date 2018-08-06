/++
  A module containing the logic for parsing and analysing the code coverage

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.coverage;

import std.algorithm;
import std.range;
import std.string;
import std.stdio;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.math;

import trial.discovery.code;

version(D_Coverage) {
  shared static this() {
    import core.runtime;

    if(exists("coverage")) {
      writeln("Creating coverage folder...");
      rmdirRecurse("coverage");
    }

    auto destination = buildPath("coverage", "raw").asAbsolutePath.array.idup.to!string;
    mkdirRecurse(destination);

    dmd_coverSetMerge(false);
    //dmd_coverSourcePath(thisExePath);
    dmd_coverDestPath(destination);
  }
}

/// Converts coverage lst files to html
double convertLstFiles(string packagePath, string packageName) {
  if(!exists(buildPath("coverage", "raw"))) {
    return 0;
  }

  if(!exists(buildPath("coverage", "html"))) {
    mkdirRecurse(buildPath("coverage", "html"));
  }

  std.file.write(buildPath("coverage", "html", "coverage.css"), import("templates/coverage.css"));

  auto coverageData =
    dirEntries(buildPath("coverage", "raw"), SpanMode.shallow)
    .filter!(f => f.name.endsWith(".lst"))
    .filter!(f => f.isFile)
    .map!(a => readText(a.name))
    .map!(a => a.toCoverageFile(packagePath)).array;

  std.file.write(buildPath("coverage", "html", "coverage-shield.svg"), coverageShield(coverageData.filter!"a.isInCurrentProject".array.coveragePercent.to!int.to!string));
  std.file.write(buildPath("coverage", "html", "index.html"), coverageData.toHtmlIndex(packageName));

  foreach (data; coverageData) {
    auto htmlFile = data.path.toCoverageHtmlFileName;

    std.file.write(buildPath("coverage", "html", htmlFile), data.toHtml);
  }

  return coverageData.coveragePercent;
}

string toCoverageHtmlFileName(string fileName) {
  return fileName.replace("/", "-").replace("\\", "-") ~ ".html";
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
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
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

  /// Is true if the file is set to be ignored
  /// from the final report
  bool isIgnored;

  /// The module name
  string moduleName;

  /// The covered percent
  double coveragePercent;

  /// The file lines with coverage data
  LineCoverage[] lines;
}

/// Check if a file should be ignored from the report
bool isIgnored(const string content) {
  auto firstLine = content.splitter('\n');

  if(firstLine.empty) {
    return false;
  }

  auto smallCase = firstLine.front.strip.toLower;
  auto pieces = smallCase.replace("\t", " ").splitter(' ').filter!(a => a != "").array;

  if(pieces[0].indexOf("//") == -1 && pieces[0].indexOf("/*") == -1 && pieces[0].indexOf("/+") == -1) {
    return false;
  }

  if(pieces.length == 2) {
    return pieces[0].indexOf("ignore") != -1 && pieces[1] == "coverage";
  }

  if(pieces.length < 3) {
    return false;
  }

  return pieces[1] == "ignore" && pieces[2] == "coverage";
}

/// It should return true for ignored coverage files
unittest {
  "// IGNORE COVERAGE".isIgnored.should.equal(true);
  "// \t IGNORE \t COVERAGE".isIgnored.should.equal(true);
  "// ignore coverage".isIgnored.should.equal(true);
  "//IGNORE COVERAGE".isIgnored.should.equal(true);
  "/////IGNORE COVERAGE".isIgnored.should.equal(true);
  "//     IGNORE     COVERAGE     ".isIgnored.should.equal(true);
  "/*     IGNORE     COVERAGE     */".isIgnored.should.equal(true);
  "/*****     IGNORE     COVERAGE  ".isIgnored.should.equal(true);
  "/*****     IGNORE     COVERAGE     ****/".isIgnored.should.equal(true);
  "/+     IGNORE     COVERAGE     +/".isIgnored.should.equal(true);
  "/+++++     IGNORE     COVERAGE  ".isIgnored.should.equal(true);
  "/+++++     IGNORE     COVERAGE     +++++/".isIgnored.should.equal(true);
}


/// It should return false for when the ignore coverage file is missing
unittest {
  "".isIgnored.should.equal(false);
  "//\nIGNORE COVERAGE".isIgnored.should.equal(false);
  "//\nIGNORE COVERAGE".isIgnored.should.equal(false);
  "/////\nIGNORE COVERAGE".isIgnored.should.equal(false);
  "//\n     IGNORE     COVERAGE     ".isIgnored.should.equal(false);
  "/*\n     IGNORE     COVERAGE     */".isIgnored.should.equal(false);
  "/*****  \n   IGNORE     COVERAGE  ".isIgnored.should.equal(false);
  "/*****  \n   IGNORE     COVERAGE     ****/".isIgnored.should.equal(false);
  "/+   \n  IGNORE     COVERAGE     +/".isIgnored.should.equal(false);
  "/+++++  \n   IGNORE     COVERAGE  ".isIgnored.should.equal(false);
  "/+++++   \n  IGNORE     COVERAGE     +++++/".isIgnored.should.equal(false);
  "// IGNORE\nCOVERAGE".isIgnored.should.equal(false);
  "//IGNORE\nCOVERAGE".isIgnored.should.equal(false);
}


/// Check if a file is in the current path
bool isPackagePath(string fullPath, string packagePath) {
  if(fullPath.indexOf("/.trial/") != -1) {
    return false;
  }

  if(fullPath.indexOf("trial_") != -1) {
    return false;
  }

  if(fullPath.indexOf(packagePath) == 0) {
    return true;
  }

  if(fullPath.replace("\\", "/").indexOf(packagePath) == 0) {
    return true;
  }

  return false;
}

/// Check project paths
unittest {
  "../../something.d".isPackagePath("/Users/trial/").should.equal(false);
  "/Users/trial/trial_.d".isPackagePath("/Users/trial/").should.equal(false);
  "/Users/trial/runner.d".isPackagePath("/Users/trial/").should.equal(true);
  "/Users/trial/.trial/runner.d".isPackagePath("/Users/trial/").should.equal(false);
  "C:\\Users\\trial\\runner.d".isPackagePath("C:/Users/trial/").should.equal(true);
}

/// Converts a .lst file content to a CoveredFile structure
CoveredFile toCoverageFile(string content, string packagePath) {
  auto fileName = content.getFileName;
  auto fullPath = buildNormalizedPath(getcwd, fileName);

  return CoveredFile(
    fileName,
    fullPath.isPackagePath(packagePath),
    content.isIgnored(),
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

/// should mark the `trial_.d` file as external file
unittest {
  auto result = `trial_package.d is 74% covered
`.toCoverageFile(buildPath(getcwd, "lifecycle/trial"));

  result.isInCurrentProject.should.equal(false);
}

/// Generate the html for a line coverage
string toLineCoverage(T)(LineCoverage line, T index) {
  return import("templates/coverageColumn.html")
            .replaceVariable("hasCode", line.hasCode ? "has-code" : "")
            .replaceVariable("hit", line.hits > 0 ? "hit" : "")
            .replaceVariable("line", index.to!string)
            .replaceVariable("hitCount", line.hits.to!string);
}

/// Render line coverage column
unittest {
  LineCoverage("    |").toLineCoverage(1).should.contain([`<span class="line-number">1</span>`, `<span class="hit-count">0</span>`]);
  LineCoverage("    |").toLineCoverage(1).should.not.contain(["has-code", `hit"`]);

  LineCoverage("    1|code").toLineCoverage(2).should.contain([ `<span class="line-number">2</span>`, `<span class="hit-count">1</span>`, "has-code", `hit"` ]);
}

/// Get the line coverage column for the html report
string toHtmlCoverage(LineCoverage[] lines) {
  return lines.enumerate(1).map!(a => a[1].toLineCoverage(a[0])).array.join("").replace("\n", "");
}

/// Cont how many lines were hit
auto hitLines(LineCoverage[] lines) {
  return lines.filter!(a => a.hits > 0).array.length;
}

/// Cont how many lines were hit
auto codeLines(LineCoverage[] lines) {
  return lines.filter!(a => a.hasCode).array.length;
}

/// Replace an `{variable}` inside a string
string replaceVariable(const string page, const string key, const string value) pure {
  return page.replace("{"~key~"}", value);
}

/// It should replace a variable inside a page
unittest {
  `-{key}-`.replaceVariable("key", "value").should.equal("-value-");
}

/// wraps some string in a html page
string wrapToHtml(string content, string title) {
  return import("templates/page.html").replaceVariable("content", content).replaceVariable("title", title);
}

///should replace the variables inside the page.html
unittest {
  auto page = wrapToHtml("some content", "some title");

  page.should.contain(`<title>some title</title>`);
  page.should.contain("<body>\n  some content\n</body>");
}

/// Create an html progress bar
string htmlProgress(string percent) {
  return import("templates/progress.html").replaceVariable("percent", percent);
}

///should replace the variables inside the page.html
unittest {
  htmlProgress("33").should.contain(`33%`);
  htmlProgress("33").should.contain(`33% Covered`);
}

/// Generate the coverage page header
string coverageHeader(CoveredFile coveredFile) {
  return import("templates/coverageHeader.html")
          .replaceVariable("title", coveredFile.moduleName)
          .replaceVariable("hitLines", coveredFile.lines.hitLines.to!string)
          .replaceVariable("totalLines", coveredFile.lines.codeLines.to!string)
          .replaceVariable("coveragePercent", coveredFile.coveragePercent.to!string)
          .replaceVariable("pathPieces", pathSplitter(coveredFile.path).array.join(`</li><li>`));
}

/// Check variables for the coverage header
unittest {
  CoveredFile coveredFile;
  coveredFile.moduleName = "module.name";
  coveredFile.coveragePercent = 30;
  coveredFile.path = "a/b";
  coveredFile.lines = [ LineCoverage("       0| not code"), LineCoverage("    1| some code") ];

  auto header = coverageHeader(coveredFile);

  header.should.contain(`<h1>module.name`);
  header.should.contain(`1/2`);
  header.should.contain(`30%`);
  header.should.contain(`<li>a</li><li>b</li>`);
}

/// Convert a `CoveredFile` struct to html
string toHtml(CoveredFile coveredFile) {
   return wrapToHtml(
     coverageHeader(coveredFile) ~
     import("templates/coverageBody.html")
          .replaceVariable("lines", coveredFile.lines.toHtmlCoverage)
          .replaceVariable("code", coveredFile.lines.map!(a => a.code.replace("<", "&lt;").replace(">", "&gt;")).array.join("\n")),

      coveredFile.moduleName ~ " coverage"
   );
}

/// Check variables for the coverage html
unittest {
  CoveredFile coveredFile;
  coveredFile.moduleName = "module.name";
  coveredFile.coveragePercent = 30;
  coveredFile.path = "a/b";
  coveredFile.lines = [ LineCoverage("       0| <not code>"), LineCoverage("    1| some code") ];

  auto html = toHtml(coveredFile);

  html.should.contain(`<h1>module.name`);
  html.should.contain(`&lt;not code&gt;`);
  html.should.contain(`<title>module.name coverage</title>`);
  html.should.contain(`hit"`);
}

string indexTable(string content) {
  return import("templates/indexTable.html").replaceVariable("content", content);
}

string ignoredTable(string content) {
  return import("templates/ignoredTable.html").replaceVariable("content", content);
}

/// Check if the table body is inserted
unittest {
  indexTable("some content").should.contain(`<tbody>some content</tbody>`);
}

/// Calculate the coverage percent from the current project
double coveragePercent(CoveredFile[] coveredFiles) {
  if(coveredFiles.length == 0) {
    return 100;
  }

  double total = 0;
  double covered = 0;

  foreach(file; coveredFiles.filter!"a.isInCurrentProject".filter!"!a.isIgnored") {
    total += file.lines.map!(a => a.hasCode ? 1 : 0).sum;
    covered += file.lines.filter!(a => a.hasCode).map!(a => a.hits > 0 ? 1 : 0).sum;
  }

  if(total == 0) {
    return 100;
  }

  return round((covered / total) * 10000) / 100;
}

/// No files are always 100% covered
unittest {
  [].coveragePercent.should.equal(100);
}

/// check a 50% covered file
unittest {
  auto coveredFile = CoveredFile("", true, false, "", 50, [ LineCoverage("     75|  this(File f)"), LineCoverage("     0|  this(File f)") ]);
  [coveredFile].coveragePercent.should.equal(50);
}

/// check a 50% external covered file
unittest {
  auto coveredFile = CoveredFile("", false, false, "", 0, [ LineCoverage("     0|  this(File f)"), LineCoverage("     0|  this(File f)") ]);
  [coveredFile].coveragePercent.should.equal(100);
}


string toHtmlIndex(CoveredFile[] coveredFiles, string name) {
  sort!("toUpper(a.path) < toUpper(b.path)", SwapStrategy.stable)(coveredFiles);
  string content;

  string table;
  size_t totalHitLines;
  size_t totalLines;
  size_t ignoredLines;
  int count;

  foreach(file; coveredFiles.filter!"a.isInCurrentProject".filter!"!a.isIgnored") {
    auto currentHitLines = file.lines.hitLines;
    auto currentTotalLines = file.lines.codeLines;

    table ~= `<tr>
      <td><a href="` ~ file.path.toCoverageHtmlFileName ~ `">` ~ file.path ~ `</a></td>
      <td>` ~ file.moduleName ~ `</td>
      <td>` ~ file.lines.hitLines.to!string ~ `/` ~ currentTotalLines.to!string ~ `</td>
      <td>` ~ file.coveragePercent.to!string.htmlProgress ~ `</td>
    </tr>`;

    totalHitLines += currentHitLines;
    totalLines += currentTotalLines;
    count++;
  }

  table ~= `<tr>
      <th colspan="2">Total</td>
      <th>` ~ totalHitLines.to!string ~ `/` ~ totalLines.to!string ~ `</td>
      <th>` ~ coveredFiles.coveragePercent.to!string.htmlProgress ~ `</td>
    </tr>`;

  content ~= indexHeader(name) ~ table.indexTable;


  /// Ignored files
  table = "";
  foreach(file; coveredFiles.filter!"a.isInCurrentProject".filter!"a.isIgnored") {
    auto currentTotalLines = file.lines.codeLines;

    table ~= `<tr>
      <td><a href="` ~ file.path.toCoverageHtmlFileName ~ `">` ~ file.path ~ `</a></td>
      <td>` ~ file.moduleName ~ `</td>
      <td>` ~ currentTotalLines.to!string ~ `/` ~ totalLines.to!string ~ `</td>
    </tr>`;

    ignoredLines += currentTotalLines;
    count++;
  }

  table ~= `<tr>
      <th colspan="2">Total</td>
      <th>` ~ ignoredLines.to!string ~ `/` ~ totalLines.to!string ~ `</td>
    </tr>`;

  content ~= `<h1>Ignored</h1>` ~ table.ignoredTable;

  /// external files
  table = "";
  foreach(file; coveredFiles.filter!"!a.isInCurrentProject") {
    table ~= `<tr>
      <td><a href="` ~ file.path.toCoverageHtmlFileName ~ `">` ~ file.path ~ `</a></td>
      <td>` ~ file.moduleName ~ `</td>
      <td>` ~ file.lines.hitLines.to!string ~ `/` ~ file.lines.codeLines.to!string ~ `</td>
      <td>` ~ file.coveragePercent.to!string.htmlProgress ~ `</td>
    </tr>`;
  }

  content ~= `<h1>Dependencies</h1>` ~ table.indexTable;

  content = `<div class="container">` ~ content ~ `</div>`;

  return wrapToHtml(content, "Code Coverage report");
}

string indexHeader(string name) {
  return `<h1>` ~ name ~ ` <img src="coverage-shield.svg"></h1>`;
}


/// Create line coverage shield as svg
string coverageShield(string percent) {
  return import("templates/coverage.svg").replace("?%", percent ~ "%");
}

/// The line coverage shield should contain the percent
unittest {
  coverageShield("30").should.contain("30%");
}