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

  void goTo(string);
  void resetLine();
  void write(string, Context = Context.active);
  void writeln(string, Context = Context.active);
}

class ConsoleWriter : ReportWriter {
  void goTo(string) {}
  void resetLine() {}

  void write(string text, Context) {
    std.stdio.write(text);
  }

  void writeln(string text, Context) {
    std.stdio.writeln(text);
  }
}

version(Have_arsd_official_terminal) {
  import terminal;

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
          case Context.inactive:
            terminal.color(Color.white | ~Bright, 255);
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

    void resetLine() {
      //this.terminal.write("*");
      terminal.moveTo(0, lines);
      //this.terminal.write("#");
    }

    void goTo(string cue) {
      if(cue !in cues) {
        cues[cue] = terminal.cursorY;
      }

      terminal.moveTo(0, cues[cue]);
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
  }
} else {
  shared static this() {
    defaultWriter = new ConsoleWriter;
  }
}

class BufferedWriter : ReportWriter {
  string buffer = "";

  private {
    long[string] cues;
    long line = 0;
    long charPos = 0;

    string[] screen;
  }

  void goTo(string cue) {
    if(cue !in cues) {
      cues[cue] = line;
    }

    line = cues[cue];
    screen[line] = "";
  }

  void resetLine() {
    if(screen.length == 0) {
      return;
    }

    screen[line] = "";
  }

  void write(string text, Context) {
    auto lines = text.count!(a => a == '\n');
    auto pieces = buffer.split("\n");

    if(screen.length == 0) {
      screen = [ text ];
    } else {
      screen[line] ~= text;
    }

    line += lines;

    buffer = screen.join("\n");
    screen = buffer.split("\n");
  }

  void writeln(string text, Context c) {
    write(text ~ '\n', c);
  }
}
