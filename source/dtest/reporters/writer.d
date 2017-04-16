module dtest.reporters.writer;

import std.stdio;

interface ReportWriter {
  enum Context {
    active,
    inactive,
    success,
    info,
    warning,
    danger
  }

  void write(string, Context = Context.active);
  void writeln(string, Context = Context.active);
}

class ConsoleWriter : ReportWriter {
  void write(string text, Context) {
    std.stdio.write(text);
  }

  void writeln(string text, Context) {
    std.stdio.writeln(text);
  }
}

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

  void write(string text, Context context) {
    setColor(context);

    std.stdio.write(text);

    resetColor;
  }

  void writeln(string text, Context context) {
    write(text ~ "\n", context);
  }
}

class BufferedWriter : ReportWriter {
  string buffer = "";

  void write(string text, Context) {
    buffer ~= text;
  }

  void writeln(string text, Context) {
    buffer ~= text ~ "\n";
  }
}
