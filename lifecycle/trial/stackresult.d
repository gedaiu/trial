module trial.stackresult;

import std.conv;
import std.regex;
import std.exception;
import std.stdio;
import std.string;
import std.algorithm;

import core.demangle;

import fluentasserts.core.base;
import fluentasserts.core.results;

TestException toTestException(Throwable t) {
  auto exception = cast(TestException) t;

  if(exception is null) {
    IResult[] results = [ cast(IResult) new MessageResult(t.classinfo.name ~ ": " ~ t.msg) ];

    if(t.file.indexOf("../") == -1) {
      results ~= cast(IResult) new SourceResult(t.file, t.line);
    }

    if(t !is null && t.info !is null) {
      results ~= cast(IResult) new StackResult(t.info);
    }

    exception = new TestException(results, t.file, t.line, t);
  }

  return exception;
}

@("toTestException should convert an Exception from the current project to a TestException with 2 reporters")
unittest {
  auto exception = new Exception("random text");
  auto testException = exception.toTestException;

  (testException !is null).should.equal(true);
  testException.toString.should.contain("random text");
  testException.toString.should.contain("lifecycle/trial/runner.d");
}

@("toTestException should convert an Exception from other project to a TestException with 1 reporter")
unittest {
  auto exception = new Exception("random text", "../file.d");
  auto testException = exception.toTestException;

  (testException !is null).should.equal(true);
  testException.toString.should.contain("random text");
  testException.toString.should.not.contain("lifecycle/trial/runner.d");
}

struct ExternalValidator {
  string[] externalModules;

  bool isExternal(const string name) {
    auto reversed = name.dup;
    reverse(reversed);

    string substring = name;
    int sum = 0;
    int index = 0;
    foreach(ch; reversed) {
      if(ch == ')') {
        sum++;
      }

      if(ch == '(') {
        sum--;
      }

      if(sum == 0) {
        break;
      }
      index++;
    }

    auto tmpSubstring = reversed[index..$];
    reverse(tmpSubstring);
    substring = tmpSubstring.to!string;

    auto wordEnd = substring.lastIndexOf(' ') + 1;
    auto chainEnd = substring.lastIndexOf(").") + 1;

    if(chainEnd > wordEnd) {
      return isExternal(name[0..chainEnd]);
    }

    auto functionName = substring[wordEnd..$];

    return !externalModules
              .filter!(a => functionName.indexOf(a) == 0)
                .empty;
  }
}

@("It should detect external functions")
unittest
{
  auto validator = ExternalValidator(["selenium.api", "selenium.session"]);

  validator.isExternal(
    "selenium.api.SeleniumApiConnector selenium.api.SeleniumApiConnector.__ctor()")
    .should.equal(true);

  validator.isExternal(
    "void selenium.api.SeleniumApiConnector.__ctor()")
    .should.equal(true);

  validator.isExternal(
    "pure @safe bool selenium.api.enforce!(Exception, bool).enforce(bool, lazy const(char)[], immutable(char)[], ulong)")
    .should.equal(true);

  validator.isExternal(
    "immutable(immutable(selenium.session.SeleniumSession) function(immutable(char)[], selenium.api.Capabilities, selenium.api.Capabilities, selenium.api.Capabilities)) selenium.session.SeleniumSession.__ctor")
    .should.equal(true);
}

class StackResult: IResult {
  static {
    string[] externalModules;
  }

  Frame[] frames;

  this(Throwable.TraceInfo t) {


    foreach(line; t) {

      auto frame = line.to!string.toFrame;
      frame.name = demangle(frame.name).to!string;
      frames ~= frame;
    }
  }

  private {
    auto getFrames() {
      return frames
        .until!(a => a.name.indexOf("generated") != -1)
        .until!(a => a.name.indexOf("D5trial") != -1);
    }
  }

  override {
    string toString() {
      string result = "Stack trace:\n-------------------\n...\n";

      foreach(frame; getFrames) {
        result ~= leftJustifier(frame.index.to!string, 4).to!string ~ frame.address ~ " " ~ frame.name ~ "\n";
      }

      return result ~ "...";
    }

    void print() {
      version(Have_consoled) {
        import consoled;

        int colorIndex=0;
        writeln("Stack trace:\n-------------------\n...\n");

        auto validator = ExternalValidator(externalModules);

        foreach(frame; getFrames) {
          if(validator.isExternal(frame.name)) {
            foreground = Color.blue;
          } else {
            foreground = Color.red;
          }

          write(leftJustifier(frame.index.to!string, 4));
          write(frame.address ~ " ");

          if(validator.isExternal(frame.name)) {
            foreground = Color.cyan;
          } else {
            foreground = Color.lightCyan;
          }

          writeln(frame.name);

          resetColors();
        }
        writeln("...");
      } else {
        writeln(toString);
      }
    }
  }
}

@("The stack result should display the stack in a readable form")
unittest
{
  Throwable exception;

  try {
    assert(false, "random message");
  } catch(Throwable t) {
    exception = t;
  }

  auto result = new StackResult(exception.info).toString;

  result.should.startWith("Stack trace:\n-------------------\n...");
  result.should.endWith("\n...");
}

struct Frame {
  int index = -1;
  string moduleName;
  string address;
  string name;
  string offset;
  string file;
  int line = -1;
}

immutable static {
  string index       = `(?P<index>[0-9]+)`;
  string moduleName  = `(?P<module>\S+)`;
  string address     = `(?P<address>0x[0-9a-fA-F]+)`;
  string name        = `(?P<name>.+)`;
  string offset      = `(?P<offset>(0x[0-9A-Za-z]+)|([0-9]+))`;
  string file        = `(?P<file>.+)`;
  string linePattern = `(?P<line>[0-9]+)`;
}

Frame toDarwinFrame(string line) {
  Frame frame;

  auto darwinPattern = index ~ `(\s+)` ~
                       moduleName ~ `(\s+)` ~
                       address ~ `(\s+)` ~
                       name ~ `\s\+\s` ~
                       offset;

  auto matched = matchFirst(line, darwinPattern);

  frame.index = matched["index"].to!int;
  frame.moduleName = matched["module"];
  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.offset = matched["offset"];

  return frame;
}

Frame toWindows1Frame(string line) {
  Frame frame;

  auto matched = matchFirst(line, address ~ `(\s+)in(\s+)` ~ name ~ `(\s+)at(\s+)`~ file ~ `\(` ~ linePattern ~ `\)`);// ~ );

  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.file = matched["file"];
  frame.line = matched["line"].to!int;


  enforce(frame.address != "", "address not found");
  enforce(frame.name != "", "name not found");
  enforce(frame.file != "", "file not found");

  return frame;
}

Frame toWindows2Frame(string line) {
  Frame frame;

  auto matched = matchFirst(line, address ~ `(\s+)in(\s+)` ~ name);
  frame.address = matched["address"];
  frame.name = matched["name"];

  enforce(frame.address != "", "address not found");
  enforce(frame.name != "", "name not found");

  return frame;
}


Frame toGLibCFrame(string line) {
  Frame frame;

  auto matched = matchFirst(line, moduleName ~ `\(` ~ name ~ `\)\s+\[` ~ address ~ `\]`);

  frame.address = matched["address"];
  frame.name = matched["name"];
  frame.moduleName = matched["module"];

  auto plusSign = frame.name.indexOf("+");

  if(plusSign != -1) {
    frame.offset = frame.name[plusSign+1..$];
    frame.name = frame.name[0..plusSign];
  }

  enforce(frame.address != "", "address not found");
  enforce(frame.name != "", "name not found");
  enforce(frame.moduleName != "", "module not found");

  return frame;
}

Frame toNetBsdFrame(string line) {
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

Frame toFrame(string line) {
  Frame frame;

  try {
    return line.toDarwinFrame;
  } catch (Exception e) {}

  try {
    return line.toWindows1Frame;
  } catch (Exception e) {}

  try {
    return line.toWindows2Frame;
  } catch (Exception e) {}

  try {
    return line.toGLibCFrame;
  } catch (Exception e) {}

  try {
    return line.toNetBsdFrame;
  } catch (Exception e) {}

  return frame;
}

@("Get frame info from Darwin platform format")
unittest {
  auto line = "1  ???fluent-asserts    0x00abcdef000000 D6module4funcAFZv + 0";

  auto frame = line.toFrame;
  frame.index.should.equal(1);
  frame.moduleName.should.equal("???fluent-asserts");
  frame.address.should.equal("0x00abcdef000000");
  frame.name.should.equal("D6module4funcAFZv");
  frame.offset.should.equal("0");
}

@("Get frame info from windows platform format without path")
unittest {
  auto line = "0x779CAB5A in RtlInitializeExceptionChain";

  auto frame = line.toFrame;
  frame.index.should.equal(-1);
  frame.moduleName.should.equal("");
  frame.address.should.equal("0x779CAB5A");
  frame.name.should.equal("RtlInitializeExceptionChain");
  frame.offset.should.equal("");
}

@("Get frame info from windows platform format with path")
unittest {
  auto line = `0x00402669 in void app.__unittestL82_8() at D:\tidynumbers\source\app.d(84)`;

  auto frame = line.toFrame;
  frame.index.should.equal(-1);
  frame.moduleName.should.equal("");
  frame.address.should.equal("0x00402669");
  frame.name.should.equal("void app.__unittestL82_8()");
  frame.file.should.equal(`D:\tidynumbers\source\app.d`);
  frame.line.should.equal(84);
  frame.offset.should.equal("");
}

@("Get frame info from CRuntime_Glibc format without offset")
unittest {
  auto line = `module(_D6module4funcAFZv) [0x00000000]`;

  auto frame = line.toFrame;

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

  frame.moduleName.should.equal("module");
  frame.name.should.equal("_D6module4funcAFZv");
  frame.address.should.equal("0x00000000");
  frame.index.should.equal(-1);
  frame.offset.should.equal("0x78");
}

@("Get frame info from NetBSD format")
unittest {
  auto line = `0x00000000 <_D6module4funcAFZv+0x78> at module`;

  auto frame = line.toFrame;

  frame.moduleName.should.equal("module");
  frame.name.should.equal("_D6module4funcAFZv");
  frame.address.should.equal("0x00000000");
  frame.index.should.equal(-1);
  frame.offset.should.equal("0x78");
}
