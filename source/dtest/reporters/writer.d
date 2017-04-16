module dtest.reporters.writer;

import std.stdio;

interface ReportWriter {
  void write(string);
  void writeln(string);
}

class ConsoleWriter : ReportWriter {
  void write(string text) {
    std.stdio.write(text);
  }

  void writeln(string text) {
    std.stdio.writeln(text);
  }
}

class BufferedWriter : ReportWriter {
  string buffer = "";

  void write(string text) {
    buffer ~= text;
  }

  void writeln(string text) {
    buffer ~= text ~ "\n";
  }
}
