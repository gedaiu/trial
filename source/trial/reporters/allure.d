/++
  A module containing the AllureReporter

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.reporters.allure;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.algorithm;
import std.file;
import std.path;
import std.uuid;
import std.range;

import trial.interfaces;
import trial.reporters.writer;

private string escape(string data) {
  string escapedData = data.dup;

  escapedData = escapedData.replace(`&`, `&amp;`);
  escapedData = escapedData.replace(`"`, `&quot;`);
  escapedData = escapedData.replace(`'`, `&apos;`);
  escapedData = escapedData.replace(`<`, `&lt;`);
  escapedData = escapedData.replace(`>`, `&gt;`);

  return escapedData;
}

/// The Allure reporter creates a xml containing the test results, the steps
/// and the attachments. http://allure.qatools.ru/
class AllureReporter : ILifecycleListener {
  private {
    immutable string destination;
  }

  this(string destination) {
    this.destination = destination;
  }

  void begin(ulong testCount) {
    if (exists(destination)) {
      std.file.rmdirRecurse(destination);
    }
  }

  void update() {
  }

  void end(SuiteResult[] result) {
    if (!exists(destination)) {
      destination.mkdirRecurse;
    }

    foreach (item; result) {
      string uuid = randomUUID.toString;
      string xml = AllureSuiteXml(destination, item, uuid).toString;

      std.file.write(buildPath(destination, uuid ~ "-testsuite.xml"), xml);
    }
  }
}

struct AllureSuiteXml {
  /// The suite result
  SuiteResult result;

  /// The suite id
  string uuid;

  /// The allure version
  const string allureVersion = "1.5.2";

  private {
    immutable string destination;
  }

  this(const string destination, SuiteResult result, string uuid) {
    this.destination = destination;
    this.result = result;
    this.uuid = uuid;
  }

  /// Converts the suiteResult to a xml string
  string toString() {
    auto epoch = SysTime.fromUnixTime(0);
    string tests = result.tests.map!(a => AllureTestXml(destination, a, uuid)
        .toString).array.join("\n");

    if (tests != "") {
      tests = "\n" ~ tests;
    }

    auto xml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:test-suite start="`
      ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" version="` ~ this.allureVersion ~ `" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
    <name>`
      ~ result.name.escape ~ `</name>
    <title>`
      ~ result.name.escape ~ `</title>
    <test-cases>`
      ~ tests ~ `
    </test-cases>
`;

    if (result.attachments.length > 0) {
      xml ~= "    <attachments>\n";
      xml ~= result.attachments
        .map!(a => AllureAttachmentXml(destination, a, 6, uuid))
        .map!(a => a.toString)
        .array
        .join('\n') ~ "\n";
      xml ~= "    </attachments>\n";
    }

    xml ~= `    <labels>
        <label name="framework" value="Trial"/>
        <label name="language" value="D"/>
    </labels>
</ns2:test-suite>`;

    return xml;
  }
}

version (unittest) {
  import fluent.asserts;
}

@("AllureSuiteXml should transform an empty suite")
unittest {
  auto epoch = SysTime.fromUnixTime(0);
  auto result = SuiteResult("Test Suite");
  result.begin = Clock.currTime;

  TestResult test = new TestResult("Test");
  test.begin = Clock.currTime;
  test.end = Clock.currTime;
  test.status = TestResult.Status.success;

  result.end = Clock.currTime;

  result.tests = [test];

  auto allure = AllureSuiteXml("allure", result, "");

  allure.toString.should.equal(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:test-suite start="`
      ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" version="1.5.2" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
    <name>`
      ~ result.name ~ `</name>
    <title>`
      ~ result.name ~ `</title>
    <test-cases>
        <test-case start="`
      ~ (test.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
            <name>Test</name>
        </test-case>
    </test-cases>
    <labels>
        <label name="framework" value="Trial"/>
        <label name="language" value="D"/>
    </labels>
</ns2:test-suite>`);
}

@("AllureSuiteXml should transform a suite with a success test")
unittest {
  auto epoch = SysTime.fromUnixTime(0);
  auto result = SuiteResult("Test Suite");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;

  auto allure = AllureSuiteXml("allure", result, "");

  allure.toString.should.equal(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:test-suite start="`
      ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" version="1.5.2" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
    <name>`
      ~ result.name ~ `</name>
    <title>`
      ~ result.name ~ `</title>
    <test-cases>
    </test-cases>
    <labels>
        <label name="framework" value="Trial"/>
        <label name="language" value="D"/>
    </labels>
</ns2:test-suite>`);
}

/// AllureSuiteXml should add the attachments
unittest {
  string resource = buildPath(getcwd(), "some_text.txt");
  std.file.write(resource, "");

  auto uuid = randomUUID.toString;

  scope (exit) {
    remove(resource);
    remove("allure/" ~ uuid ~ "/title.0.some_text.txt");
  }

  auto epoch = SysTime.fromUnixTime(0);

  auto result = SuiteResult("Test Suite");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.attachments = [Attachment("title", resource, "plain/text")];

  auto allure = AllureSuiteXml("allure", result, uuid);

  allure.toString.should.equal(
    `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:test-suite start="`
      ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" version="1.5.2" xmlns:ns2="urn:model.allure.qatools.yandex.ru">
    <name>`
      ~ result.name ~ `</name>
    <title>`
      ~ result.name ~ `</title>
    <test-cases>
    </test-cases>
    <attachments>
      <attachment title="title" source="`
      ~ uuid ~ `/title.0.some_text.txt" type="plain/text" />
    </attachments>
    <labels>
        <label name="framework" value="Trial"/>
        <label name="language" value="D"/>
    </labels>
</ns2:test-suite>`);
}

struct AllureTestXml {
  ///
  TestResult result;

  ///
  string uuid;

  private {
    immutable string destination;
  }

  this(const string destination, TestResult result, string uuid) {
    this.destination = destination;
    this.result = result;
    this.uuid = uuid;
  }

  /// Converts a test result to allure status
  string allureStatus() {
    switch (result.status) {
    case TestResult.Status.created:
      return "canceled";

    case TestResult.Status.failure:
      return "failed";

    case TestResult.Status.skip:
      return "canceled";

    case TestResult.Status.success:
      return "passed";

    default:
      return "unknown";
    }
  }

  /// Return the string representation of the test
  string toString() {
    auto epoch = SysTime.fromUnixTime(0);
    auto start = (result.begin - epoch).total!"msecs";
    auto stop = (result.end - epoch).total!"msecs";

    string xml = `        <test-case start="` ~ start.to!string ~ `" stop="` ~ stop.to!string ~ `" status="` ~ allureStatus ~ `">` ~ "\n";
    xml ~= `            <name>` ~ result.name.escape ~ `</name>` ~ "\n";

    if (result.labels.length > 0) {
      xml ~= "            <labels>\n";

      foreach (label; result.labels) {
        xml ~= "              <label name=\"" ~ label.name ~ "\" value=\"" ~ label.value ~ "\"/>\n";
      }

      xml ~= "            </labels>\n";
    }

    if (result.throwable !is null) {
      xml ~= `            <failure>
                <message>`
        ~ result.throwable.msg.escape ~ `</message>
                <stack-trace>`
        ~ result.throwable.to!string.escape ~ `</stack-trace>
            </failure>`
        ~ "\n";
    }

    if (result.steps.length > 0) {
      xml ~= "            <steps>\n";
      xml ~= result.steps
        .map!(a => AllureStepXml(destination, a, 14, uuid))
        .map!(a => a.toString)
        .array
        .join('\n') ~ "\n";
      xml ~= "            </steps>\n";
    }

    if (result.attachments.length > 0) {
      xml ~= "            <attachments>\n";
      xml ~= result.attachments
        .map!(a => AllureAttachmentXml(destination, a, 14, uuid))
        .map!(a => a.toString)
        .array
        .join('\n') ~ "\n";
      xml ~= "            </attachments>\n";
    }

    xml ~= `        </test-case>`;

    return xml;
  }
}

@("AllureTestXml should transform a success test")
unittest {
  auto epoch = SysTime.fromUnixTime(0);

  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.success;

  auto allure = AllureTestXml("allure", result, "");

  allure.toString.should.equal(
    `        <test-case start="` ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
            <name>Test</name>
        </test-case>`);
}

@("AllureTestXml should transform a failing test")
unittest {
  import trial.step;

  Step("prepare the test data");
  auto epoch = SysTime.fromUnixTime(0);
  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.failure;
  result.throwable = new Exception("message");

  Step("create the report listener");
  auto allure = AllureTestXml("allure", result, "");

  Step("perform checks");
  allure.toString.should.equal(
    `        <test-case start="` ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="failed">
            <name>Test</name>
            <failure>
                <message>message</message>
                <stack-trace>object.Exception@source/trial/reporters/allure.d(`
      ~ result.throwable.line.to!string ~ `): message</stack-trace>
            </failure>
        </test-case>`);
}

/// AllureTestXml should transform a test with steps
unittest {
  auto epoch = SysTime.fromUnixTime(0);

  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.success;

  StepResult step = new StepResult();
  step.name = "some step";
  step.begin = result.begin;
  step.end = result.end;

  result.steps = [step, step];

  auto allure = AllureTestXml("allure", result, "");

  allure.toString.should.equal(
    `        <test-case start="` ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
            <name>Test</name>
            <steps>
                <step start="`
      ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
                  <name>some step</name>
                </step>
                <step start="`
      ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
                  <name>some step</name>
                </step>
            </steps>
        </test-case>`);
}

/// AllureTestXml should transform a test with labels
unittest {
  auto epoch = SysTime.fromUnixTime(0);

  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.success;
  result.labels ~= Label("status_details", "flaky");

  auto allure = AllureTestXml("allure", result, "");

  allure.toString.should.equal(
    `        <test-case start="` ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
            <name>Test</name>
            <labels>
              <label name="status_details" value="flaky"/>
            </labels>
        </test-case>`);
}

/// AllureTestXml should add the attachments
unittest {
  string resource = buildPath(getcwd(), "some_text.txt");
  std.file.write(resource, "");

  auto uuid = randomUUID.toString;

  scope (exit) {
    if (exists(resource)) {
      remove(resource);
    }

    remove("allure/" ~ uuid ~ "/title.0.some_text.txt");
  }

  auto epoch = SysTime.fromUnixTime(0);

  TestResult result = new TestResult("Test");
  result.begin = Clock.currTime;
  result.end = Clock.currTime;
  result.status = TestResult.Status.success;
  result.attachments = [Attachment("title", resource, "plain/text")];

  auto allure = AllureTestXml("allure", result, uuid);

  allure.toString.should.equal(
    `        <test-case start="` ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
            <name>Test</name>
            <attachments>
              <attachment title="title" source="`
      ~ uuid ~ `/title.0.some_text.txt" type="plain/text" />
            </attachments>
        </test-case>`);
}

struct AllureStepXml {
  private {
    StepResult step;
    size_t indent;
    string uuid;

    immutable string destination;
  }

  this(const string destination, StepResult step, size_t indent, string uuid) {
    this.step = step;
    this.indent = indent;
    this.uuid = uuid;
    this.destination = destination;
  }

  /// Return the string representation of the step
  string toString() {
    auto epoch = SysTime.fromUnixTime(0);
    const spaces = "  " ~ (" ".repeat(indent).array.join());
    string result = spaces ~ `<step start="` ~ (step.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (step.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">` ~ "\n" ~
      spaces ~ `  <name>` ~ step.name.escape ~ `</name>` ~ "\n";

    if (step.steps.length > 0) {
      result ~= spaces ~ "  <steps>\n";
      result ~= step.steps
        .map!(a => AllureStepXml(destination, a, indent + 6, uuid))
        .map!(a => a.to!string)
        .array
        .join('\n') ~ "\n";
      result ~= spaces ~ "  </steps>\n";
    }

    if (step.attachments.length > 0) {
      result ~= spaces ~ "  <attachments>\n";
      result ~= step.attachments
        .map!(a => AllureAttachmentXml(destination, a, indent + 6, uuid))
        .map!(a => a.to!string)
        .array
        .join('\n') ~ "\n";
      result ~= spaces ~ "  </attachments>\n";
    }

    result ~= spaces ~ `</step>`;

    return result;
  }
}

/// AllureStepXml should transform a step
unittest {
  auto epoch = SysTime.fromUnixTime(0);
  StepResult result = new StepResult();
  result.name = "step";
  result.begin = Clock.currTime;
  result.end = Clock.currTime;

  auto allure = AllureStepXml("allure", result, 0, "");

  allure.toString.should.equal(
    `  <step start="` ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
    <name>step</name>
  </step>`);
}

/// AllureStepXml should transform nested steps
unittest {
  auto epoch = SysTime.fromUnixTime(0);
  StepResult result = new StepResult();
  result.name = "step";
  result.begin = Clock.currTime;
  result.end = Clock.currTime;

  StepResult step = new StepResult();
  step.name = "some step";
  step.begin = result.begin;
  step.end = result.end;

  result.steps = [step, step];

  auto allure = AllureStepXml("allure", result, 0, "");

  allure.toString.should.equal(
    `  <step start="` ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
    <name>step</name>
    <steps>
        <step start="`
      ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
          <name>some step</name>
        </step>
        <step start="`
      ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
          <name>some step</name>
        </step>
    </steps>
  </step>`);
}

/// AllureStepXml should add the attachments
unittest {
  string resource = buildPath(getcwd(), "some_image.png");
  scope (exit) {
    resource.remove();
  }
  std.file.write(resource, "");

  auto uuid = randomUUID.toString;

  scope (exit) {
    rmdirRecurse("allure");
  }

  auto epoch = SysTime.fromUnixTime(0);
  StepResult result = new StepResult();
  result.name = "step";
  result.begin = Clock.currTime;
  result.end = Clock.currTime;

  result.attachments = [Attachment("name", resource, "image/png")];

  auto allure = AllureStepXml("allure", result, 0, uuid);

  allure.toString.should.equal(
    `  <step start="` ~ (result.begin - epoch).total!"msecs"
      .to!string ~ `" stop="` ~ (result.end - epoch).total!"msecs"
      .to!string ~ `" status="passed">
    <name>step</name>
    <attachments>
      <attachment title="name" source="`
      ~ uuid ~ `/name.0.some_image.png" type="image/png" />
    </attachments>
  </step>`);
}

/// Allure representation of an atachment.
/// It will copy the file to the allure folder with an unique name
struct AllureAttachmentXml {

  private {
    const {
      Attachment attachment;
      size_t indent;
    }

    string allureFile;
  }

  @disable this();

  /// Init the struct and copy the atachment to the allure folder
  this(const string destination, Attachment attachment, size_t indent, string uuid) {
    this.indent = indent;

    if (!exists(buildPath(destination, uuid))) {
      buildPath(destination, uuid).mkdirRecurse;
    }

    ulong index;

    do {
      allureFile = buildPath(uuid, attachment.name ~ "." ~ index.to!string ~ "." ~ baseName(
          attachment.file));
      index++;
    }
    while (buildPath(destination, allureFile).exists);

    if (attachment.file.exists) {
      std.file.copy(attachment.file, buildPath(destination, allureFile));
    }

    this.attachment = Attachment(attachment.name, buildPath(destination, allureFile), attachment
        .mime);
  }

  /// convert the attachment to string
  string toString() {
    return (" ".repeat(indent).array.join()) ~ "<attachment title=\"" ~ attachment.name ~
      "\" source=\"" ~ allureFile ~
      "\" type=\"" ~ attachment.mime ~ "\" />";
  }
}

/// Allure attachments should be copied to a folder containing the suite name
unittest {
  string resource = buildPath(getcwd(), "some_image.png");
  std.file.write(resource, "");

  auto uuid = randomUUID.toString;
  auto expectedPath = buildPath(getcwd(), "allure", uuid, "name.0.some_image.png");

  scope (exit) {
    rmdirRecurse("allure");
  }

  auto a = AllureAttachmentXml("allure", Attachment("name", resource, ""), 0, uuid);

  expectedPath.exists.should.equal(true);
}

/// Allure attachments should avoid name collisions
unittest {
  string resource = buildPath(getcwd(), "some_image.png");
  std.file.write(resource, "");

  auto uuid = randomUUID.toString;

  buildPath(getcwd(), "allure", uuid).mkdirRecurse;
  auto expectedPath = buildPath(getcwd(), "allure", uuid, "name.1.some_image.png");
  auto existingPath = buildPath(getcwd(), "allure", uuid, "name.0.some_image.png");
  std.file.write(existingPath, "");

  scope (exit) {
    rmdirRecurse("allure");
  }

  auto a = AllureAttachmentXml("allure", Attachment("name", resource, ""), 0, uuid);

  expectedPath.exists.should.equal(true);
}
