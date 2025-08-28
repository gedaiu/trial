module trial.testNameProvider;

import std.conv;
import std.file;
import std.algorithm;
import std.string;
import std.array;
import std.range;
import std.typecons;

version(unittest) {
  version(Have_fluent_asserts) {
    import fluent.asserts;
  }
}

struct Comment {
  ulong line;
  string value;
}

enum CommentType {
  none,
  begin,
  end,
  comment
}

Comment[] commentGroupToString(T)(T[] group)
{
  if (group.front[1] == CommentType.comment)
  {
    auto slice = group.until!(a => a[1] != CommentType.comment).array;

    string value = slice.map!(a => a[2].stripLeft('/').array.to!string).map!(a => a.strip)
      .join(' ').array.to!string;

    return [Comment(slice[slice.length - 1][0], value)];
  }

  if (group.front[1] == CommentType.begin)
  {
    auto ch = group.front[2][1];
    auto index = 0;

    auto newGroup = group.map!(a => Tuple!(int, CommentType, immutable(char),
        string)(a[0], a[1], a[2].length > 2 ? a[2][1] : ' ', a[2])).array;

    foreach (item; newGroup)
    {
      index++;
      if (item[1] == CommentType.end && item[2] == ch)
      {
        break;
      }
    }

    auto slice = group.map!(a => Tuple!(int, CommentType, immutable(char), string)(a[0],
        a[1], a[2].length > 2 ? a[2][1] : ' ', a[2])).take(index);

    string value = slice.map!(a => a[3].strip).map!(a => a.stripLeft('/')
        .stripLeft(ch).array.to!string).map!(a => a.strip).join(' ')
      .until(ch ~ "/").array.stripRight('/').stripRight(ch).strip.to!string;

    return [Comment(slice[slice.length - 1][0], value)];
  }

  return [];
}

CommentType commentType(T)(T line) {
  if (line.length < 2) {
    return CommentType.none;
  }

  if (line[0 .. 2] == "//") {
    return CommentType.comment;
  }

  if (line[0 .. 2] == "/+" || line[0 .. 2] == "/*") {
    return CommentType.begin;
  }

  if (line.indexOf("+/") != -1 || line.indexOf("*/") != -1) {
    return CommentType.end;
  }

  return CommentType.none;
}

bool connects(T)(T a, T b) {
  auto items = a[0] < b[0] ? [a, b] : [b, a];

  if (items[1][0] - items[0][0] != 1) {
    return false;
  }

  if (a[1] == b[1]) {
    return true;
  }

  if (items[0][1] != CommentType.end && items[1][1] != CommentType.begin) {
    return true;
  }

  return false;
}


Comment[] compressComments(string code) {
  Comment[] result;

  auto lines = code.splitter("\n").map!(a => a.strip).enumerate(1)
    .map!(a => Tuple!(int, CommentType, string)(a[0], a[1].commentType, a[1])).filter!(
        a => a[2] != "").array;

  auto tmp = [lines[0]];
  auto prev = lines[0];

  foreach (line; lines[1 .. $])
  {
    if (tmp.length == 0 || line.connects(tmp[tmp.length - 1])) {
      tmp ~= line;
    } else {
      result ~= tmp.commentGroupToString;
      tmp = [line];
    }
  }

  if (tmp.length > 0) {
    result ~= tmp.commentGroupToString;
  }

  return result;
}

@("It should group comments")
unittest {
  string comments = "//line 1
	// line 2

	//// other line

	/** line 3
	line 4 ****/

	//// other line

	/++ line 5
	line 6
	+++/

	/** line 7
   *
   * line 8
   */";

  auto results = comments.compressComments;

  results.length.should.equal(6);
  results[0].value.should.equal("line 1 line 2");
  results[1].value.should.equal("other line");
  results[2].value.should.equal("line 3 line 4");
  results[3].value.should.equal("other line");
  results[4].value.should.equal("line 5 line 6");
  results[5].value.should.equal("line 7  line 8");

  results[0].line.should.equal(2);
  results[1].line.should.equal(4);
  results[2].line.should.equal(7);
  results[3].line.should.equal(9);
  results[4].line.should.equal(13);
}

export class TestNameProvider {
  static private TestNameProvider _instance;

  static instance() {
    if(!this._instance) {
      this._instance = new TestNameProvider();
    }
    return this._instance;
  }

  static reset() {
      this._instance = null;
  }

  Comment[][string] comments;

  void loadComments(string fileName) {
    if(!fileName.exists) {
      import std.stdio : writeln;
      writeln("Warning: Can't load comments for ", fileName, ". It does not exist!");
      return;
    }

    comments[fileName] = fileName.readText.compressComments;
  }
}

string getName(alias T)(TestNameProvider instance) {
  enum location = __traits(getLocation, T);
  enum defaultName = location[0] ~ ":" ~ location[1].to!string;
  string name = defaultName;
  Comment[string][] comments;

  static foreach (attr; __traits(getAttributes, T)) {
    static if (is(typeof(attr) == string))
    {
      name = attr;
    }
  }

  instance.loadComments(location[0]);

  if(location[0] !in instance.comments) {
    return name;
  }

  foreach (comment; instance.comments[location[0]].filter!(a => a.line - location[1] > -3)) {
    name = comment.value;
  }

  return name;
}

/// it can get a name from a string attribute
unittest {
  TestNameProvider.reset();

  @("some nice name")
  void testFunc() { }

  const name = TestNameProvider.instance.getName!testFunc();

  name.should.equal("some nice name");
}

/// it returns the filename and line by default
unittest {
  TestNameProvider.reset();

  void testFunc() {}

  const name = TestNameProvider.instance.getName!testFunc();
  enum location = __traits(getLocation, testFunc);

  name.should.equal("source/trial/testNameProvider.d:" ~ location[1].to!string);
}

/// it returns the comment when the text function is commented
unittest {
  TestNameProvider.reset();

  /// some nice name
  void testFunc() { }

  const name = TestNameProvider.instance.getName!testFunc();

  name.should.equal("some nice name");
}



/// it returns the comment when the text function is commented on 3 lines
unittest {
  TestNameProvider.reset();

  /// some
  /// nice
  /// name
  void testFunc() { }

  const name = TestNameProvider.instance.getName!testFunc();

  name.should.equal("some nice name");
}
