/++
  A module containing custom exceptions for display convenience

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.stackresult;

import std.conv;
import std.regex;
import std.exception;
import std.stdio;
import std.string;
import std.algorithm;

import core.demangle;

version (unittest) {
  version (Have_fluent_asserts) {
    import fluent.asserts;
  }
}

auto toTestException(Throwable t)
{
  return t;
}

/// Used to display the stack
class StackResult
{
  static
  {
    ///
    string[] externalModules;
  }

  ///
  Frame[] frames;

  ///
  this(Throwable.TraceInfo t)
  {
    foreach (line; t)
    {
      auto frame = line.to!string.toFrame;
      frame.name = demangle(frame.name).to!string;
      frames ~= frame;
    }
  }

  private
  {
    auto getFrames()
    {
      return frames.until!(a => a.name.indexOf("generated") != -1)
        .until!(a => a.name.indexOf("D5trial") != -1);
    }
  }

  /// Converts the result to a string
  override string toString() @safe
  {
    string result = "Stack trace:\n-------------------\n...\n";

    foreach (frame; getFrames)
    {
      result ~= frame.toString ~ "\n";
    }

    return result ~ "...";
  }
}

/// Represents a stack frame
struct Frame
{
  ///
  int index = -1;

  ///
  string moduleName;

  ///
  string address;

  ///
  string name;

  ///
  string offset;

  ///
  string file;

  ///
  int line = -1;

  ///
  bool invalid = true;

  ///
  string raw;

  string toString() const @safe {
    if(raw != "") {
      return raw;
    }

    string result;

    if(index >= 0) {
      result ~= leftJustifier(index.to!string, 4).to!string;
    }

    result ~= address ~ " ";
    result ~= name == "" ? "????" : name;

    if(moduleName != "") {
      result ~= " at " ~ moduleName;
    }

    if(offset != "") {
      result ~= " + " ~ offset;
    }

    if(file != "") {
      result ~= " (" ~ file;

      if(line > 0) {
        result ~= ":" ~ line.to!string;
      }

      result ~= ")";
    }

    return result;
  }
}

/// The frame should convert a frame to string
unittest
{
  Frame(10, "some.module", "0xffffff", "name", "offset", "file.d", 120).toString.should.equal(
    `10  0xffffff name at some.module + offset (file.d:120)`
  );
}

/// The frame should not output an index < 0 or a line < 0
unittest
{
  Frame(-1, "some.module", "0xffffff", "name", "offset", "file.d", -1).toString.should.equal(
    `0xffffff name at some.module + offset (file.d)`
  );
}

/// The frame should not output the file if it is missing from the stack
unittest
{
  Frame(-1, "some.module", "0xffffff", "name", "offset", "", 10).toString.should.equal(
    `0xffffff name at some.module + offset`
  );
}

/// The frame should not output the module if it is missing from the stack
unittest
{
  Frame(-1, "", "0xffffff", "name", "offset", "", 10).toString.should.equal(
    `0xffffff name + offset`
  );
}

/// The frame should not output the offset if it is missing from the stack
unittest
{
  Frame(-1, "", "0xffffff", "name", "", "", 10).toString.should.equal(
    `0xffffff name`
  );
}

/// The frame should display `????` when the name is missing
unittest
{
  Frame(-1, "", "0xffffff", "", "", "", 10).toString.should.equal(
    `0xffffff ????`
  );
}

immutable static
{
  string index = `(?P<index>[0-9]+)`;
  string moduleName = `(?P<module>\S+)`;
  string address = `(?P<address>0x[0-9a-fA-F]+)`;
  string name = `(?P<name>.+)`;
  string offset = `(?P<offset>(0x[0-9A-Za-z]+)|([0-9]+))`;
  string file = `(?P<file>.+)`;
  string linePattern = `(?P<line>[0-9]+)`;
}

/// Parse a MacOS string frame
Frame toDarwinFrame(string line)
{
  Frame frame;

  auto darwinPattern = index ~ `(\s+)` ~ moduleName ~ `(\s+)` ~ address ~ `(\s+)`
    ~ name ~ `\s\+\s` ~ offset;

  auto matched = matchFirst(line, darwinPattern);

  if(matched.length < 5) {
    return frame;
  }

  frame.invalid = false;
  frame.index = matched["index"].to!int;
  frame.moduleName = matched["module"];
  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.offset = matched["offset"];

  return frame;
}

/// Parse a Windows string frame
Frame toWindows1Frame(string line)
{
  Frame frame;

  auto matched = matchFirst(line,
      address ~ `(\s+)in(\s+)` ~ name ~ `(\s+)at(\s+)` ~ file ~ `\(` ~ linePattern ~ `\)`); // ~ );

  if(matched.length < 4) {
    return frame;
  }

  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.file = matched["file"];
  frame.line = matched["line"].to!int;

  frame.invalid = frame.address == "" || frame.name == "" || frame.file == "";

  return frame;
}

/// ditto
Frame toWindows2Frame(string line)
{
  Frame frame;

  auto matched = matchFirst(line, address ~ `(\s+)in(\s+)` ~ name);

  if(matched.length < 2) {
    return frame;
  }

  frame.address = matched["address"];
  frame.name = matched["name"];

  frame.invalid = frame.address == "" || frame.name == "";

  return frame;
}

/// Parse a GLibC string frame
Frame toGLibCFrame(string line)
{
  Frame frame;

  auto matched = matchFirst(line, moduleName ~ `\(` ~ name ~ `\)\s+\[` ~ address ~ `\]`);

  if(matched.length < 3) {
    return frame;
  }

  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.moduleName = matched["module"];

  auto plusSign = frame.name.indexOf("+");

  if (plusSign != -1)
  {
    frame.offset = frame.name[plusSign + 1 .. $];
    frame.name = frame.name[0 .. plusSign];
  }

  frame.invalid = frame.address == "" || frame.name == "" || frame.moduleName == "" ||
  frame.name.indexOf("(") >= 0;
  return frame;
}

/// Parse a NetBsd string frame
Frame toNetBsdFrame(string line)
{
  Frame frame;

  auto matched = matchFirst(line, address ~ `\s+<` ~ name ~ `\+` ~ offset ~ `>\s+at\s+` ~ moduleName);

  if(matched.length < 4) {
    return frame;
  }

  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.moduleName = matched["module"];
  frame.offset = matched["offset"];

  frame.invalid = frame.address == "" || frame.name == "" || frame.moduleName == "" || frame.offset == "";

  return frame;
}

/// Parse a Linux frame
Frame toLinuxFrame(string line) {
  Frame frame;

  auto matched = matchFirst(line, file ~ `:` ~ linePattern ~ `\s+` ~ name ~ `\s+\[` ~ address ~ `\]`);

  if(matched.length < 4) {
    return frame;
  }

  frame.file = matched["file"];
  frame.name = matched["name"];
  frame.address = matched["address"];
  frame.line = matched["line"].to!int;

  frame.invalid = frame.address == "" || frame.name == "" || frame.file == "" || frame.line == 0;

  return frame;
}

/// Parse a Linux frame
Frame toMissingInfoLinuxFrame(string line) {
  Frame frame;

  auto matched = matchFirst(line, `\?\?:\?\s+` ~ name ~ `\s+\[` ~ address ~ `\]`);

  if(matched.length < 2) {
    return frame;
  }

  frame.name = matched["name"];
  frame.address = matched["address"];

  frame.invalid = frame.address == "" || frame.name == "";

  return frame;
}

/// Converts a stack trace line to a Frame structure
Frame toFrame(string line)
{
  Frame frame;
  frame.raw = line;
  frame.invalid = false;

  auto frames = [
    line.toDarwinFrame,
    line.toWindows1Frame,
    line.toWindows2Frame,
    line.toLinuxFrame,
    line.toGLibCFrame,
    line.toNetBsdFrame,
    line.toMissingInfoLinuxFrame,
    frame
  ];

  return frames.filter!(a => !a.invalid).front;
}

@("Get frame info from Darwin platform format")
unittest {
  auto line = "1  ???fluent-asserts    0x00abcdef000000 D6module4funcAFZv + 0";

  auto frame = line.toFrame;
  frame.invalid.should.equal(false);
  frame.index.should.equal(1);
  frame.moduleName.should.equal("???fluent-asserts");
  frame.address.should.equal("0x00abcdef000000");
  frame.name.should.equal("D6module4funcAFZv");
  frame.offset.should.equal("0");
}

@("Get frame info from windows platform format without path")
unittest
{
  auto line = "0x779CAB5A in RtlInitializeExceptionChain";

  auto frame = line.toFrame;
  frame.invalid.should.equal(false);
  frame.index.should.equal(-1);
  frame.moduleName.should.equal("");
  frame.address.should.equal("0x779CAB5A");
  frame.name.should.equal("RtlInitializeExceptionChain");
  frame.offset.should.equal("");
}

@("Get frame info from windows platform format with path")
unittest
{
  auto line = `0x00402669 in void app.__unitestL82_8() at D:\tidynumbers\source\app.d(84)`;

  auto frame = line.toFrame;
  frame.invalid.should.equal(false);
  frame.index.should.equal(-1);
  frame.moduleName.should.equal("");
  frame.address.should.equal("0x00402669");
  frame.name.should.equal("void app.__unitestL82_8()");
  frame.file.should.equal(`D:\tidynumbers\source\app.d`);
  frame.line.should.equal(84);
  frame.offset.should.equal("");
}

@("Get frame info from CRuntime_Glibc format without offset")
unittest {
  auto line = `module(_D6module4funcAFZv) [0x00000000]`;

  auto frame = line.toFrame;

  frame.invalid.should.equal(false);
  frame.moduleName.should.equal("module");
  frame.name.should.equal("_D6module4funcAFZv");
  frame.address.should.equal("0x00000000");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}

@("Get frame info from CRuntime_Glibc format with offset")
unittest {
  auto line = `module(_D6module4funcAFZv+0x78) [0x00000000]`;

  auto frame = line.toFrame;

  frame.invalid.should.equal(false);
  frame.moduleName.should.equal("module");
  frame.name.should.equal("_D6module4funcAFZv");
  frame.address.should.equal("0x00000000");
  frame.index.should.equal(-1);
  frame.offset.should.equal("0x78");
}

@("Get frame info from NetBSD format")
unittest
{
  auto line = `0x00000000 <_D6module4funcAFZv+0x78> at module`;

  auto frame = line.toFrame;

  frame.invalid.should.equal(false);
  frame.moduleName.should.equal("module");
  frame.name.should.equal("_D6module4funcAFZv");
  frame.address.should.equal("0x00000000");
  frame.index.should.equal(-1);
  frame.offset.should.equal("0x78");
}

/// Get the main frame info from linux format
unittest {
  auto line = `generated.d:45 _Dmain [0x8e80c4]`;

  auto frame = line.toFrame;

  frame.invalid.should.equal(false);
  frame.moduleName.should.equal("");
  frame.file.should.equal("generated.d");
  frame.line.should.equal(45);
  frame.name.should.equal("_Dmain");
  frame.address.should.equal("0x8e80c4");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}

/// Get a function frame info from linux format
unittest {
  auto line = `lifecycle/trial/runner.d:106 trial.interfaces.SuiteResult[] trial.runner.runTests(const(trial.interfaces.TestCase)[], immutable(char)[]) [0x8b0ec1]`;
  auto frame = line.toFrame;

  frame.invalid.should.equal(false);
  frame.moduleName.should.equal("");
  frame.file.should.equal("lifecycle/trial/runner.d");
  frame.line.should.equal(106);
  frame.name.should.equal("trial.interfaces.SuiteResult[] trial.runner.runTests(const(trial.interfaces.TestCase)[], immutable(char)[])");
  frame.address.should.equal("0x8b0ec1");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}

/// Get an external function frame info from linux format
unittest {
  auto line = `../../.dub/packages/fluent-asserts-0.6.6/fluent-asserts/core/fluentasserts/core/base.d:39 void fluentasserts.core.base.Result.perform() [0x8f4b47]`;
  auto frame = line.toFrame;

  frame.invalid.should.equal(false);
  frame.moduleName.should.equal("");
  frame.file.should.equal("../../.dub/packages/fluent-asserts-0.6.6/fluent-asserts/core/fluentasserts/core/base.d");
  frame.line.should.equal(39);
  frame.name.should.equal("void fluentasserts.core.base.Result.perform()");
  frame.address.should.equal("0x8f4b47");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}

/// Get an external function frame info from linux format
unittest {
  auto line = `lifecycle/trial/discovery/unit.d:268 _D5trial9discovery4unit17UnitTestDiscovery231__T12addTestCasesVAyaa62_2f686f6d652f626f737a2f776f726b73706163652f64746573742f6c6966656379636c652f747269616c2f6578656375746f722f706172616c6c656c2e64VAyaa23_747269616c2e6578656375746f722e706172616c6c656cS245trial8executor8parallelZ12addTestCasesMFZ9__lambda4FZv [0x872000]`;
  auto frame = line.toFrame;

  frame.invalid.should.equal(false);
  frame.moduleName.should.equal("");
  frame.file.should.equal("lifecycle/trial/discovery/unit.d");
  frame.line.should.equal(268);
  frame.name.should.equal("_D5trial9discovery4unit17UnitTestDiscovery231__T12addTestCasesVAyaa62_2f686f6d652f626f737a2f776f726b73706163652f64746573742f6c6966656379636c652f747269616c2f6578656375746f722f706172616c6c656c2e64VAyaa23_747269616c2e6578656375746f722e706172616c6c656cS245trial8executor8parallelZ12addTestCasesMFZ9__lambda4FZv");
  frame.address.should.equal("0x872000");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}

/// Get an internal function frame info from linux format
unittest {
  auto line = `../../../../../fluent-asserts/source/fluentasserts/core/operations/arrayEqual.d:26 nothrow @safe fluentasserts.core.results.IResult[] fluentasserts.core.operations.arrayEqual.arrayEqual(ref fluentasserts.core.evaluation.Evaluation) [0x27a57ce]`;
  auto frame = line.toFrame;

  frame.invalid.should.equal(false);
  frame.moduleName.should.equal("");
  frame.file.should.equal("../../../../../fluent-asserts/source/fluentasserts/core/operations/arrayEqual.d");
  frame.line.should.equal(26);
  frame.name.should.equal("nothrow @safe fluentasserts.core.results.IResult[] fluentasserts.core.operations.arrayEqual.arrayEqual(ref fluentasserts.core.evaluation.Evaluation)");
  frame.address.should.equal("0x27a57ce");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}

/// Get an missing info function frame info from linux format
unittest {
  auto line = `??:? __libc_start_main [0x174bbf44]`;
  auto frame = line.toFrame;

  frame.invalid.should.equal(false);
  frame.moduleName.should.equal("");
  frame.file.should.equal("");
  frame.line.should.equal(-1);
  frame.name.should.equal("__libc_start_main");
  frame.address.should.equal("0x174bbf44");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}
