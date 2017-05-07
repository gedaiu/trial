module trial.reporters.writer;

import std.stdio;
import std.algorithm;
import std.string;

interface ReportWriter {
  enum Context {
    active,
    inactive,
    success,
    info,
    warning,
    danger
  }

  void goTo(string);
  void write(string, Context = Context.active);
  void writeln(string, Context = Context.active);
}

class ConsoleWriter : ReportWriter {
  void goTo(string) {}

  void write(string text, Context) {
    std.stdio.write(text);
  }

  void writeln(string text, Context) {
    std.stdio.writeln(text);
  }
}

version(Have_consoled) {
  class ColorConsoleWriter : ReportWriter {
    private {
      void setColor(Context context) {
        import consoled;

        switch(context) {
          case Context.inactive:
            foreground = Color.lightGray;
            break;

          case Context.success:
            foreground = Color.lightGreen;
            break;

          case Context.info:
            foreground = Color.cyan;
            break;

          case Context.warning:
            foreground = Color.yellow;
            break;

          case Context.danger:
            foreground = Color.red;
            break;

          default:
            foreground = Color.initial;
        }
      }

      void resetColor() {
        import consoled;
        foreground = Color.initial;
      }
    }

    void goTo(string cue) {
    }

    void write(string text, Context context) {
      setColor(context);

      std.stdio.write(text);

      resetColor;
    }

    void writeln(string text, Context context) {
      write(text ~ "\n", context);
    }
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
    std.stdio.writeln("go to ", cue);

    if(cue !in cues) {
      cues[cue] = line;
    }

    line = cues[cue];
    screen[line] = "";
  }

  void write(string text, Context) {
    auto lines = text.count!(a => a == '\n');
    auto pieces = buffer.split("\n");

    std.stdio.writeln("1.", screen);
    if(screen.length == 0) {
      screen = [ text ];
    } else {
      screen[line] ~= text;
    }

    line += lines;

    buffer = screen.join("\n");
    screen = buffer.split("\n");
    std.stdio.writeln("2.", screen);
  }

  void writeln(string text, Context c) {
    write(text ~ '\n', c);
  }
}
