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

version (Have_fluent_asserts) { } else {
  auto toTestException(Throwable t)
  {
    return t;
  }
}

version (Have_fluent_asserts) {

  import fluentasserts.core.base;
  import fluentasserts.core.results;

  ///
  class TestExceptionWrapper : TestException {
    private {
      TestException exception;
      IResult[] results;
    }

    ///
    this(TestException exception, IResult[] results, string fileName, size_t line, Throwable next = null) {
      this.exception = exception;
      this.results = results;

      super(results, fileName, line, next);

      this.msg = exception.msg ~ "\n" ~ this.msg;
    }

    ///
    override void print(ResultPrinter printer) {
      exception.print(printer);

      results.each!(a => a.print(printer));
    }

    ///
    override string toString() {
      return exception.toString ~ results.map!(a => a.toString).join("\n").to!string;
    }
  }

  /// The message of a wrapped exception should contain the original exception
  unittest {
    auto exception = new TestException([ new MessageResult("first message") ], "", 0);
    auto wrappedException = new TestExceptionWrapper(exception, [ new MessageResult("second message") ], "", 0);

    wrappedException.msg.should.equal("first message\n\nsecond message\n");
  }

/// Converts a Throwable to a TestException which improves the failure verbosity
TestException toTestException(Throwable t)
{
  auto exception = cast(TestException) t;

  if (exception is null)
  {
    IResult[] results = [cast(IResult) new MessageResult(t.classinfo.name ~ ": " ~ t.msg)];

    if (t.file.indexOf("../") == -1)
    {
      results ~= cast(IResult) new SourceResult(t.file, t.line);
    }

    if (t !is null && t.info !is null)
    {
      results ~= cast(IResult) new StackResult(t.info);
    }

    exception = new TestException(results, t.file, t.line, t);
  } else {
    exception = new TestExceptionWrapper(exception, [ cast(IResult) new StackResult(t.info) ], t.file, t.line, t);
  }

  return exception;
}


@("toTestException should convert an Exception from the current project to a TestException with 2 reporters")
unittest
{
  auto exception = new Exception("random text");
  auto testException = exception.toTestException;

  (testException !is null).should.equal(true);
  testException.toString.should.contain("random text");
  testException.toString.should.contain("lifecycle/trial/runner.d");
}

@("toTestException should convert an Exception from other project to a TestException with 1 reporter")
unittest
{
  auto exception = new Exception("random text", "../file.d");
  auto testException = exception.toTestException;

  (testException !is null).should.equal(true);
  testException.toString.should.contain("random text");
  testException.toString.should.not.contain("lifecycle/trial/runner.d");
}

/// A structure that allows you to detect which modules are relevant to display
struct ExternalValidator
{

  /// The list of external modules like the standard library or dub dependencies
  string[] externalModules;

  /// Check if the provided name comes from an external dependency
  bool isExternal(const string name) @safe
  {
    auto reversed = name.dup;
    reverse(reversed);

    string substring = name;
    int sum = 0;
    int index = 0;
    foreach (ch; reversed)
    {
      if (ch == ')')
      {
        sum++;
      }

      if (ch == '(')
      {
        sum--;
      }

      if (sum == 0)
      {
        break;
      }
      index++;
    }

    auto tmpSubstring = reversed[index .. $];
    reverse(tmpSubstring);
    substring = tmpSubstring.to!string;

    auto wordEnd = substring.lastIndexOf(' ') + 1;
    auto chainEnd = substring.lastIndexOf(").") + 1;

    if (chainEnd > wordEnd)
    {
      return isExternal(name[0 .. chainEnd]);
    }

    auto functionName = substring[wordEnd .. $];

    return !externalModules.filter!(a => functionName.indexOf(a) == 0).empty;
  }
}

@("It should detect external functions")
unittest
{
  auto validator = ExternalValidator(["selenium.api", "selenium.session"]);

  validator.isExternal("selenium.api.SeleniumApiConnector selenium.api.SeleniumApiConnector.__ctor()")
    .should.equal(true);

  validator.isExternal("void selenium.api.SeleniumApiConnector.__ctor()").should.equal(true);

  validator.isExternal(
      "pure @safe bool selenium.api.enforce!(Exception, bool).enforce(bool, lazy const(char)[], immutable(char)[], ulong)")
    .should.equal(true);

  validator.isExternal("immutable(immutable(selenium.session.SeleniumSession) function(immutable(char)[], selenium.api.Capabilities, selenium.api.Capabilities, selenium.api.Capabilities)) selenium.session.SeleniumSession.__ctor")
    .should.equal(true);
}

/// Used to display the stack
class StackResult : IResult
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

  override
  {
    /// Converts the result to a string
    string toString() @safe
    {
      string result = "Stack trace:\n-------------------\n...\n";

      foreach (frame; getFrames)
      {
        result ~= frame.toString ~ "\n";
      }

      return result ~ "...";
    }

    /// Prints the stack using the default writer
    void print(ResultPrinter printer)
    {
      int colorIndex = 0;
      printer.primary("Stack trace:\n-------------------\n...\n");

      auto validator = ExternalValidator(externalModules);

      foreach (frame; getFrames)
      {
        if (validator.isExternal(frame.name))
        {
          printer.primary(frame.toString);
        }
        else
        {
          frame.print(printer);
        }

        printer.primary("\n");
      }

      printer.primary("...");
    }
  }
}

@("The stack result should display the stack in a readable form")
unittest
{
  Throwable exception;

  try
  {
    assert(false, "random message");
  }
  catch (Throwable t)
  {
    exception = t;
  }

  auto result = new StackResult(exception.info).toString;

  result.should.startWith("Stack trace:\n-------------------\n...");
  result.should.endWith("\n...");
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

  string toString() const @safe {
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

  void print(ResultPrinter printer) @safe
  {
    if(index >= 0) {
      printer.info(leftJustifier(index.to!string, 4).to!string);
    }

    printer.primary(address ~ " ");
    printer.info(name == "" ? "????" : name);

    if(moduleName != "") {
      printer.primary(" at ");
      printer.info(moduleName);
    }

    if(offset != "") {
      printer.primary(" + ");
      printer.info(offset);
    }

    if(file != "") {
      printer.primary(" (");
      printer.info(file);

      if(line > 0) {
        printer.primary(":");
        printer.info(line.to!string);
      }

      printer.primary(")");
    }
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

version(unittest) {
  class MockPrinter : ResultPrinter {
    string buffer;

    void primary(string val) {
      buffer ~= val;
    }

    void info(string val) {
      buffer ~= "[info:" ~ val ~ "]";
    }

    void danger(string val) {
      buffer ~= "[danger:" ~ val ~ "]";
    }

    void success(string val) {
      buffer ~= "[success:" ~ val ~ "]";
    }

    void dangerReverse(string val) {
      buffer ~= "[dangerReverse:" ~ val ~ "]";
    }

    void successReverse(string val) {
      buffer ~= "[successReverse:" ~ val ~ "]";
    }
  }
}

/// The frame should print all fields
unittest
{
  auto printer = new MockPrinter;
  Frame(10, "some.module", "0xffffff", "name", "offset", "file.d", 120).print(printer);

  printer.buffer.should.equal(
    `[info:10  ]0xffffff [info:name] at [info:some.module] + [info:offset] ([info:file.d]:[info:120])`
  );
}

/// The frame should not print an index < 0 or a line < 0
unittest
{
  auto printer = new MockPrinter;
  Frame(-1, "some.module", "0xffffff", "name", "offset", "file.d", -1).print(printer);

  printer.buffer.should.equal(
    `0xffffff [info:name] at [info:some.module] + [info:offset] ([info:file.d])`
  );
}

/// The frame should not print the file if it's missing
unittest
{
  auto printer = new MockPrinter;
  Frame(-1, "some.module", "0xffffff", "name", "offset", "", 10).print(printer);

  printer.buffer.should.equal(
    `0xffffff [info:name] at [info:some.module] + [info:offset]`
  );
}

/// The frame should not print the module if it's missing
unittest
{
  auto printer = new MockPrinter;
  Frame(-1, "", "0xffffff", "name", "offset", "", 10).print(printer);

  printer.buffer.should.equal(
    `0xffffff [info:name] + [info:offset]`
  );
}

/// The frame should not print the offset if it's missing
unittest
{
  auto printer = new MockPrinter;
  Frame(-1, "", "0xffffff", "name", "", "", 10).print(printer);

  printer.buffer.should.equal(
    `0xffffff [info:name]`
  );
}

/// The frame should print ???? when the name is missing
unittest
{
  auto printer = new MockPrinter;
  Frame(-1, "", "0xffffff", "", "", "", 10).print(printer);

  printer.buffer.should.equal(
    `0xffffff [info:????]`
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

  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.file = matched["file"];
  frame.line = matched["line"].to!int;

  enforce(frame.address != "", "address not found");
  enforce(frame.name != "", "name not found");
  enforce(frame.file != "", "file not found");

  return frame;
}

/// ditto
Frame toWindows2Frame(string line)
{
  Frame frame;

  auto matched = matchFirst(line, address ~ `(\s+)in(\s+)` ~ name);
  frame.address = matched["address"];
  frame.name = matched["name"];

  enforce(frame.address != "", "address not found");
  enforce(frame.name != "", "name not found");

  return frame;
}

/// Parse a GLibC string frame
Frame toGLibCFrame(string line)
{
  Frame frame;

  auto matched = matchFirst(line, moduleName ~ `\(` ~ name ~ `\)\s+\[` ~ address ~ `\]`);

  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.moduleName = matched["module"];

  auto plusSign = frame.name.indexOf("+");

  if (plusSign != -1)
  {
    frame.offset = frame.name[plusSign + 1 .. $];
    frame.name = frame.name[0 .. plusSign];
  }

  enforce(frame.address != "", "address not found");
  enforce(frame.name != "", "name not found");
  enforce(frame.name.indexOf("(") == -1, "name should not contain `(`");
  enforce(frame.moduleName != "", "module not found");

  return frame;
}

/// Parse a NetBsd string frame
Frame toNetBsdFrame(string line)
{
  Frame frame;

  auto matched = matchFirst(line, address ~ `\s+<` ~ name ~ `\+` ~ offset ~ `>\s+at\s+` ~ moduleName);

  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.moduleName = matched["module"];
  frame.offset = matched["offset"];

  enforce(frame.address != "", "address not found");
  enforce(frame.name != "", "name not found");
  enforce(frame.moduleName != "", "module not found");
  enforce(frame.offset != "", "offset not found");

  return frame;
}

/// Parse a Linux frame
Frame toLinuxFrame(string line) {
  Frame frame;

  auto matched = matchFirst(line, file ~ `:` ~ linePattern ~ `\s+` ~ name ~ `\s+\[` ~ address ~ `\]`);

  frame.file = matched["file"];
  frame.name = matched["name"];
  frame.address = matched["address"];
  frame.line = matched["line"].to!int;

  enforce(frame.address != "", "address not found");
  enforce(frame.name != "", "name not found");
  enforce(frame.file != "", "file not found");
  enforce(frame.line > 0, "line not found");

  return frame;
}

/// Parse a Linux frame
Frame toMissingInfoLinuxFrame(string line) {
  Frame frame;

  auto matched = matchFirst(line, `\?\?:\?\s+` ~ name ~ `\s+\[` ~ address ~ `\]`);

  frame.name = matched["name"];
  frame.address = matched["address"];

  enforce(frame.address != "", "address not found");
  enforce(frame.name != "", "name not found");

  return frame;
}

/// Converts a stack trace line to a Frame structure
Frame toFrame(string line)
{
  Frame frame;

  try
  {
    return line.toDarwinFrame;
  }
  catch (Exception e)
  {
  }

  try
  {
    return line.toWindows1Frame;
  }
  catch (Exception e)
  {
  }

  try
  {
    return line.toWindows2Frame;
  }
  catch (Exception e)
  {
  }

  try
  {
    return line.toGLibCFrame;
  }
  catch (Exception e)
  {
  }

  try
  {
    return line.toNetBsdFrame;
  }
  catch (Exception e)
  {
  }

  try
  {
    return line.toLinuxFrame;
  }
  catch (Exception e)
  {
  }

  try
  {
    return line.toMissingInfoLinuxFrame;
  }
  catch (Exception e)
  {
  }

  return frame;
}

@("Get frame info from Darwin platform format")
unittest
{
  auto line = "1  ???fluent-asserts    0x00abcdef000000 D6module4funcAFZv + 0";

  auto frame = line.toFrame;
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
  frame.index.should.equal(-1);
  frame.moduleName.should.equal("");
  frame.address.should.equal("0x00402669");
  frame.name.should.equal("void app.__unitestL82_8()");
  frame.file.should.equal(`D:\tidynumbers\source\app.d`);
  frame.line.should.equal(84);
  frame.offset.should.equal("");
}

@("Get frame info from CRuntime_Glibc format without offset")
unittest
{
  auto line = `module(_D6module4funcAFZv) [0x00000000]`;

  auto frame = line.toFrame;

  frame.moduleName.should.equal("module");
  frame.name.should.equal("_D6module4funcAFZv");
  frame.address.should.equal("0x00000000");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}

@("Get frame info from CRuntime_Glibc format with offset")
unittest
{
  auto line = `module(_D6module4funcAFZv+0x78) [0x00000000]`;

  auto frame = line.toFrame;

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

  frame.moduleName.should.equal("");
  frame.file.should.equal("lifecycle/trial/discovery/unit.d");
  frame.line.should.equal(268);
  frame.name.should.equal("_D5trial9discovery4unit17UnitTestDiscovery231__T12addTestCasesVAyaa62_2f686f6d652f626f737a2f776f726b73706163652f64746573742f6c6966656379636c652f747269616c2f6578656375746f722f706172616c6c656c2e64VAyaa23_747269616c2e6578656375746f722e706172616c6c656cS245trial8executor8parallelZ12addTestCasesMFZ9__lambda4FZv");
  frame.address.should.equal("0x872000");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}


/// Get an missing info function frame info from linux format
unittest {
  auto line = `??:? __libc_start_main [0x174bbf44]`;
  auto frame = line.toFrame;

  frame.moduleName.should.equal("");
  frame.file.should.equal("");
  frame.line.should.equal(-1);
  frame.name.should.equal("__libc_start_main");
  frame.address.should.equal("0x174bbf44");
  frame.index.should.equal(-1);
  frame.offset.should.equal("");
}

/*

lifecycle/trial/executor/single.d:96 void trial.executor.single.DefaultExecutor.createTestResult(const(trial.interfaces.TestCase)) [0x8653dd6]
lifecycle/trial/executor/single.d:130 trial.interfaces.SuiteResult[] trial.executor.single.DefaultExecutor.execute(ref const(trial.interfaces.TestCase)) [0x86540f0]
lifecycle/trial/runner.d:456 trial.interfaces.SuiteResult[] trial.runner.LifeCycleListeners.execute(ref const(trial.interfaces.TestCase)) [0x86773fd]
lifecycle/trial/runner.d:284 trial.interfaces.SuiteResult[] trial.runner.runTests(const(trial.interfaces.TestCase)[], immutable(char)[]) [0x86768a7]
lifecycle/trial/interfaces.d:477 void trial.interfaces.__unittestL464_146() [0x8655f7a]
??:? void trial.interfaces.__modtest() [0x86589b0]
??:? int core.runtime.runModuleUnitTests().__foreachbody2(object.ModuleInfo*) [0x8770420]
??:? int object.ModuleInfo.opApply(scope int delegate(object.ModuleInfo*)).__lambda2(immutable(object.ModuleInfo*)) [0x8745e20]
??:? int rt.minfo.moduleinfos_apply(scope int delegate(immutable(object.ModuleInfo*))).__foreachbody2(ref rt.sections_elf_shared.DSO) [0x874f2ca]
*/



}