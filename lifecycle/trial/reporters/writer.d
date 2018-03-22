/++
  A module containing utilities for presenting information to the user

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.writer;

import std.stdio;
import std.algorithm;
import std.string;

version (Have_fluent_asserts) {
  version = Have_fluent_asserts_core;
}

/// The default writer is initialized at the test run initialization with the right
/// class, depending on the hosts capabilities.
ReportWriter defaultWriter;

/// The writer interface is used to present information to the user.
interface ReportWriter
{

  /// The information type.
  /// Convey meaning through color with a handful of emphasis utility classes.
  enum Context
  {
    /// Some important information
    active,

    /// Less important information
    inactive,

    ///
    success,

    /// Something that the user should notice
    info,

    /// Something that the user should be aware of
    warning,

    /// Something that the user must notice
    danger,

    ///
    _default
  }

  /// Go back a few lines
  void goTo(int);

  /// Write a string
  void write(string, Context = Context.active);

  /// Write a string with reversed colors
  void writeReverse(string, Context = Context.active);

  /// Write a string and go to a new line
  void writeln(string, Context = Context.active);

  /// Show the cursor from user
  void showCursor();

  /// Hide the cursor from user
  void hideCursor();

  /// Get how many characters you can print on a line
  uint width();
}

/// The console writer outputs data to the standard output. It does not
/// support colors and cursor moving.
/// This is the default writer if arsd.terminal is not present.
class ConsoleWriter : ReportWriter
{

  /// not supported
  void goTo(int)
  {
  }

  ///
  void write(string text, Context)
  {
    std.stdio.write(text);
  }

  ///
  void writeReverse(string text, Context)
  {
    std.stdio.write(text);
  }

  ///
  void writeln(string text, Context)
  {
    std.stdio.writeln(text);
  }

  /// not supported
  void showCursor()
  {
  }

  /// not supported
  void hideCursor()
  {
  }

  /// returns 80
  uint width()
  {
    return 80;
  }
}

import trial.terminal;

shared static this()
{
  version (Windows)
  {
    import core.sys.windows.windows;

    SetConsoleCP(65001);
    SetConsoleOutputCP(65001);

    auto consoleType = GetFileType(GetStdHandle(STD_OUTPUT_HANDLE));

    if(consoleType == 2) {
      writeln("using the color console.");
      defaultWriter = new ColorConsoleWriter;
    } else {
      writeln("using the standard console.");
      defaultWriter = new ConsoleWriter;
    }
    std.stdio.stdout.flush;
  } else {
    defaultWriter = new ColorConsoleWriter;
  }
}


/// This writer uses arsd.terminal and it's used if you add this dependency to your project
/// It supports all the features and you should use it if you want to get the best experience
/// from this project
class ColorConsoleWriter : ReportWriter
{
  private
  {
    int[string] cues;
    Terminal terminal;

    int lines = 0;
    bool movedToBottom = false;
    Context currentContext = Context._default;
    bool isReversed = false;
  }

  this()
  {
    this.terminal = Terminal(ConsoleOutputType.linear);
    this.terminal._suppressDestruction = true;

    lines = this.terminal.cursorY;
  }

  void setColor(Context context)
  {
    if (!isReversed && context == currentContext)
    {
      return;
    }

    isReversed = false;
    currentContext = context;

    switch (context)
    {
    case Context.active:
      terminal.color(Color.white | Bright, Color.DEFAULT);
      break;

    case Context.inactive:
      terminal.color(Color.black | Bright, Color.DEFAULT);
      break;

    case Context.success:
      terminal.color(Color.green | Bright, Color.DEFAULT);
      break;

    case Context.info:
      terminal.color(Color.cyan, Color.DEFAULT);
      break;

    case Context.warning:
      terminal.color(Color.yellow, Color.DEFAULT);
      break;

    case Context.danger:
      terminal.color(Color.red, Color.DEFAULT);
      break;

    default:
      terminal.reset();
    }
  }

  void setColorReverse(Context context)
  {
    if (!isReversed && context == currentContext)
    {
      return;
    }

    currentContext = context;
    isReversed = true;

    switch (context)
    {
    case Context.active:
      terminal.color(Color.DEFAULT, Color.white | Bright);
      break;

    case Context.inactive:
      terminal.color(Color.DEFAULT, Color.black | Bright);
      break;

    case Context.success:
      terminal.color(Color.DEFAULT, Color.green | Bright);
      break;

    case Context.info:
      terminal.color(Color.DEFAULT, Color.cyan);
      break;

    case Context.warning:
      terminal.color(Color.DEFAULT, Color.yellow);
      break;

    case Context.danger:
      terminal.color(Color.DEFAULT, Color.red);
      break;

    default:
      terminal.reset();
    }
  }

  void resetColor()
  {
    setColor(Context._default);
  }

  /// Go up `y` lines
  void goTo(int y)
  {
    if (!movedToBottom)
    {
      movedToBottom = true;
      terminal.moveTo(0, terminal.height - 1);
    }
    terminal.moveTo(0, terminal.cursorY - y, ForceOption.alwaysSend);
  }

  /// writes a string
  void write(string text, Context context)
  {
    lines += text.count!(a => a == '\n');

    setColor(context);

    terminal.write(text);
    terminal.flush;
    resetColor;
    terminal.flush;
  }

  /// writes a string with reversed colors
  void writeReverse(string text, Context context)
  {
    lines += text.count!(a => a == '\n');

    setColorReverse(context);

    terminal.write(text);
    resetColor;
    terminal.flush;
  }

  /// writes a string and go to a new line
  void writeln(string text, Context context)
  {
    this.write(text ~ "\n", context);
  }

  /// show the terminal cursor
  void showCursor()
  {
    terminal.showCursor;
  }

  /// hide the terminal cursor
  void hideCursor()
  {
    terminal.hideCursor;
  }

  /// returns the terminal width
  uint width()
  {
    return terminal.width;
  }
}

/// You can use this writer if you don't want to keep the data in memmory
/// It's useful for unit testing. It supports line navigation, with no color
/// The context info might be added in the future, once a good format is found.
class BufferedWriter : ReportWriter
{

  /// The buffer used to write the data
  string buffer = "";

  private
  {
    size_t line = 0;
    size_t charPos = 0;
    bool replace;

    string[] screen;
  }

  /// go uo y lines
  void goTo(int y)
  {
    line = line - y;
    charPos = 0;
  }

  /// returns 80
  uint width()
  {
    return 80;
  }

  ///
  void write(string text, Context)
  {
    auto lines = text.count!(a => a == '\n');
    auto pieces = buffer.split("\n");

    auto newLines = text.split("\n");

    for (auto i = line; i < line + newLines.length; i++)
    {
      if (i != line)
      {
        charPos = 0;
      }

      while (i >= screen.length)
      {
        screen ~= "";
      }

      auto newLine = newLines[i - line];

      if (charPos + newLine.length >= screen[i].length)
      {
        screen[i] = screen[i][0 .. charPos] ~ newLine;
      }
      else
      {
        screen[i] = screen[i][0 .. charPos] ~ newLine ~ screen[i][charPos + newLine.length .. $];
      }
      charPos = charPos + newLine.length;
    }

    buffer = screen.join("\n");
    screen = buffer.split("\n");
    line += lines;
  }

  ///
  void writeReverse(string text, Context c)
  {
    write(text, c);
  }

  ///
  void writeln(string text, Context c)
  {
    write(text ~ '\n', c);
  }

  /// does nothing
  void showCursor()
  {
  }

  /// does nothing
  void hideCursor()
  {
  }
}

version (unittest)
{
  version(Have_fluent_asserts_core) {
    import fluent.asserts;
  }
}

@("Buffered writer should return an empty buffer")
unittest
{
  auto writer = new BufferedWriter;
  writer.buffer.should.equal("");
}

@("Buffered writer should print text")
unittest
{
  auto writer = new BufferedWriter;
  writer.write("1", ReportWriter.Context._default);
  writer.buffer.should.equal("1");
}

@("Buffered writer should print text and add a new line")
unittest
{
  auto writer = new BufferedWriter;
  writer.write("1", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.buffer.should.equal("12\n");
}

@("Buffered writer should print text and a new line")
unittest
{
  auto writer = new BufferedWriter;
  writer.writeln("1", ReportWriter.Context._default);
  writer.write("2", ReportWriter.Context._default);
  writer.buffer.should.equal("1\n2");
}

@("Buffered writer should go back 1 line")
unittest
{
  auto writer = new BufferedWriter;
  writer.writeln("1", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.goTo(2);
  writer.writeln("3", ReportWriter.Context._default);
  writer.buffer.should.equal("3\n2\n");
}

@("Buffered writer should not replace a line if the new text is shorter")
unittest
{
  auto writer = new BufferedWriter;
  writer.writeln("11", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.goTo(2);
  writer.writeln("3", ReportWriter.Context._default);
  writer.buffer.should.equal("31\n2\n");
}

@("Buffered writer should keep the old line number")
unittest
{
  auto writer = new BufferedWriter;
  writer.writeln("1", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.goTo(2);
  writer.writeln("", ReportWriter.Context._default);
  writer.writeln("3", ReportWriter.Context._default);
  writer.buffer.should.equal("1\n3\n");
}

@("Buffered writer should keep the old line char position")
unittest
{
  auto writer = new BufferedWriter;
  writer.writeln("1", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.goTo(2);
  writer.write("3", ReportWriter.Context._default);
  writer.write("3", ReportWriter.Context._default);
  writer.buffer.should.equal("33\n2\n");
}
