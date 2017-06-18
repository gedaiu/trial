module trial.coverage;

import std.algorithm;
import std.range;
import std.string;
import std.stdio;
import std.conv;

/// Get the line that contains the coverage summary
auto getCoverageSummary(string fileContent) {
  return fileContent
      .splitLines
      .reverse
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

struct LineCoverage {
  string code;
  size_t hits;
  bool hasCode;

  @disable this();

  this(string line) {

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
      .map!(a =>LineCoverage(a));
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
}
