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

/// The default writer is initialized at the test run initialization with the right 
/// class, depending on the hosts capabilities.
ReportWriter defaultWriter;

/// The writer interface is used to present information to the user.
interface ReportWriter {
  
  /// The information type.
  /// Convey meaning through color with a handful of emphasis utility classes.
  enum Context {
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
class ConsoleWriter : ReportWriter {

  /// not supported
  void goTo(int) {}

  ///
  void write(string text, Context) {
    std.stdio.write(text);
  }

  /// 
  void writeln(string text, Context) {
    std.stdio.writeln(text);
  }

  /// not supported
  void showCursor() {}

  /// not supported
  void hideCursor() {}
  
  /// returns 80
  uint width() {
    return 80;
  }
}

version(Have_arsd_official_terminal) {
  static import arsd.terminal;

  shared static this() {
    defaultWriter = new ColorConsoleWriter;
  }

  /// This writer uses arsd.terminal and it's used if you add this dependency to your project
  /// It supports all the features and you should use it if you want to get the best experience
  /// from this project
  class ColorConsoleWriter : ReportWriter {
    private {
      int[string] cues;
      arsd.terminal.Terminal terminal;
      alias Color = arsd.terminal.Color;
      alias Bright = arsd.terminal.Bright;
      alias ForceOption = arsd.terminal.ForceOption;

      int lines = 0;

      void setColor(Context context) {
        switch(context) {
          case Context.active:
            terminal.color(Color.white | Bright, 255);
            break;

          case Context.inactive:
            terminal.color(Color.black | Bright, 255);
            break;

          case Context.success:
            terminal.color(Color.green | Bright, 255);
            break;

          case Context.info:
            terminal.color(Color.cyan, 255);
            break;

          case Context.warning:
            terminal.color(Color.yellow, 255);
            break;

          case Context.danger:
            terminal.color(Color.red, 255);
            break;

          default:
            terminal.reset();
        }
      }

      void resetColor() {
        setColor(Context._default);
      }
    }

    this() {
      this.terminal = arsd.terminal.Terminal(arsd.terminal.ConsoleOutputType.linear);
      this.terminal._suppressDestruction = true;

      lines = this.terminal.cursorY;
    }

    /// Go up `y` lines
    void goTo(int y) {
      terminal.moveTo(0, terminal.cursorY - y, ForceOption.alwaysSend);
    }

    /// writes a string
    void write(string text, Context context) {
      lines += text.count!(a => a == '\n');

      setColor(context);

      terminal.write(text);
      resetColor;
      terminal.flush;
    }

    /// writes a string and go to a new line
    void writeln(string text, Context context) {
      write(text ~ "\n", context);
    }

    /// show the terminal cursor
    void showCursor() {
      terminal.showCursor;
    }

    /// hide the terminal cursor
    void hideCursor() {
      terminal.hideCursor;
    }

    /// returns the terminal width
    uint width() {
      return terminal.width;
    }
  }
} else {
  shared static this() {
    defaultWriter = new ConsoleWriter;
  }
}

/// You can use this writer if you don't want to keep the data in memmory
/// It's useful for unit testing. It supports line navigation, with no color
/// The context info might be added in the future, once a good format is found.
class BufferedWriter : ReportWriter {

  /// The buffer used to write the data
  string buffer = "";

  private {
    long line = 0;
    long charPos = 0;
    bool replace;

    string[] screen;
  }

  /// go uo y lines
  void goTo(int y) {
    line = line - y;
    charPos = 0;
  }

  /// returns 80
  uint width() {
    return 80;
  }

  ///
  void write(string text, Context) {
    auto lines = text.count!(a => a == '\n');
    auto pieces = buffer.split("\n");

    auto newLines = text.split("\n");

    for(auto i=line; i<line + newLines.length; i++) {
      if(i != line) {
        charPos = 0;
      }

      while(i >= screen.length) {
        screen ~= "";
      }

      auto newLine = newLines[i - line];

      if(charPos + newLine.length >= screen[i].length) {
        screen[i] = screen[i][0..charPos] ~ newLine;
      } else {
        screen[i] = screen[i][0..charPos] ~ newLine ~ screen[i][charPos+newLine.length .. $];
      }
      charPos = charPos + newLine.length;
    }


    buffer = screen.join("\n");
    screen = buffer.split("\n");
    line += lines;
  }

  ///
  void writeln(string text, Context c) {
    write(text ~ '\n', c);
  }

  /// does nothing
  void showCursor() {}

  /// does nothing
  void hideCursor() {}
}

version(unittest) {
  import fluent.asserts;
}

@("Buffered writer should return an empty buffer")
unittest {
  auto writer = new BufferedWriter;
  writer.buffer.should.equal("");
}

@("Buffered writer should print text")
unittest {
  auto writer = new BufferedWriter;
  writer.write("1", ReportWriter.Context._default);
  writer.buffer.should.equal("1");
}

@("Buffered writer should print text and add a new line")
unittest {
  auto writer = new BufferedWriter;
  writer.write("1", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.buffer.should.equal("12\n");
}

@("Buffered writer should print text and a new line")
unittest {
  auto writer = new BufferedWriter;
  writer.writeln("1", ReportWriter.Context._default);
  writer.write("2", ReportWriter.Context._default);
  writer.buffer.should.equal("1\n2");
}

@("Buffered writer should go back 1 line")
unittest {
  auto writer = new BufferedWriter;
  writer.writeln("1", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.goTo(2);
  writer.writeln("3", ReportWriter.Context._default);
  writer.buffer.should.equal("3\n2\n");
}

@("Buffered writer should not replace a line if the new text is shorter")
unittest {
  auto writer = new BufferedWriter;
  writer.writeln("11", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.goTo(2);
  writer.writeln("3", ReportWriter.Context._default);
  writer.buffer.should.equal("31\n2\n");
}

@("Buffered writer should keep the old line number")
unittest {
  auto writer = new BufferedWriter;
  writer.writeln("1", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.goTo(2);
  writer.writeln("", ReportWriter.Context._default);
  writer.writeln("3", ReportWriter.Context._default);
  writer.buffer.should.equal("1\n3\n");
}

@("Buffered writer should keep the old line char position")
unittest {
  auto writer = new BufferedWriter;
  writer.writeln("1", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.goTo(2);
  writer.write("3", ReportWriter.Context._default);
  writer.write("3", ReportWriter.Context._default);
  writer.buffer.should.equal("33\n2\n");
}
