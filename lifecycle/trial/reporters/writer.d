module trial.reporters.writer;

import std.stdio;
import std.algorithm;
import std.string;

ReportWriter defaultWriter;

interface ReportWriter {
  enum Context {
    active,
    inactive,
    success,
    info,
    warning,
    danger,
    _default
  }

  void goTo(int);
  void write(string, Context = Context.active);
  void writeln(string, Context = Context.active);
  void showCursor();
  void hideCursor();
  uint width();
}

class ConsoleWriter : ReportWriter {
  void goTo(int) {}

  void write(string text, Context) {
    std.stdio.write(text);
  }

  void writeln(string text, Context) {
    std.stdio.writeln(text);
  }

  void showCursor() {}
  void hideCursor() {}
  uint width() {
    return 80;
  }
}

version(Have_arsd_official_terminal) {
  import arsd.terminal;

  shared static this() {
    defaultWriter = new ColorConsoleWriter;
  }

  class ColorConsoleWriter : ReportWriter {
    private {
      int[string] cues;
      Terminal terminal;
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
      this.terminal = Terminal(ConsoleOutputType.cellular);
      this.terminal._suppressDestruction = true;

      lines = this.terminal.cursorY;
    }

    void goTo(int y) {
      terminal.moveTo(0, terminal.cursorY - y, ForceOption.alwaysSend);
    }

    void write(string text, Context context) {
      lines += text.count!(a => a == '\n');

      setColor(context);

      terminal.write(text);
      resetColor;
      terminal.flush;
    }

    void writeln(string text, Context context) {
      write(text ~ "\n", context);
    }

    void showCursor() {
      terminal.showCursor;
    }

    void hideCursor() {
      terminal.hideCursor;
    }

    uint width() {
      return terminal.width;
    }
  }
} else {
  shared static this() {
    defaultWriter = new ConsoleWriter;
  }
}

class BufferedWriter : ReportWriter {
  string buffer = "";

  private {
    long line = 0;
    long charPos = 0;
    bool replace;

    string[] screen;
  }

  void goTo(int y) {
    line = line - y;
    charPos = 0;
  }

  uint width() {
    return 80;
  }

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

  void writeln(string text, Context c) {
    write(text ~ '\n', c);
  }

  void showCursor() {}
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

@("Buffered writer should print text and a new line")
unittest {
  auto writer = new BufferedWriter;
  writer.write("1", ReportWriter.Context._default);
  writer.writeln("2", ReportWriter.Context._default);
  writer.buffer.should.equal("12\n");
}

@("Buffered writer should print text and a new line")
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
