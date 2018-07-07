const fs = require("fs");
const fse = require('fs-extra')
const path = require("path");
const MarkdownIt = require('markdown-it');

var md = new MarkdownIt();

fse.ensureDirSync("web/assets");
fse.copySync("assets", "web/assets");
convert("", "template/_index.html", "web/index.html");
convert("", "template/_download.html", "web/download.html");
convert("../README.md", "template/_about.html", "web/about.html");
convert("../doc/attachments.md", "template/_doc.html", "web/doc/attachments.html");
convert("../doc/attributes.md", "template/_doc.html", "web/doc/attributes.html");
convert("../doc/executors.md", "template/_doc.html", "web/doc/executors.html");
convert("../doc/plugins.md", "template/_doc.html", "web/doc/plugins.html");
convert("../doc/reporters.md", "template/_doc.html", "web/doc/reporters.html");
convert("../doc/steps.md", "template/_doc.html", "web/doc/steps.html");
convert("../doc/test-discovery.md", "template/_doc.html", "web/doc/test-discovery.html");


///
function getPackage(extension) {
  var packageLocation = "../tmp";
  var result = fs.readdirSync(packageLocation).filter(a => a.endsWith(extension));

  if (result.length > 0) {
    return result[0];
  }

  return "";
}

///
function getVersion(extension) {
  var versionLocation = "../runner/trial/version_.d";
  var versionLine = fs.readFileSync(versionLocation)
    .toString()
    .split("\n")
    .filter(a => a.indexOf("trialVersion") != -1)[0];

  var version = versionLine
    .split("\"")[1];

  return version;
}

///
function convert(sourcePath, templatePath, destination) {
  var parentDestination = path.dirname(destination);

  fse.ensureDirSync(parentDestination);

  var template = fs.readFileSync(templatePath).toString();

  var result = "";

  if(sourcePath != "") {
    var source = fs.readFileSync(sourcePath)
      .toString()
      .split("\n")
      .filter(a => a.indexOf("![Build Status]") == -1)
      .filter(a => a.indexOf("![Line Coverage]") == -1)
      .filter(a => a.indexOf("![DUB Version]") == -1)
      .join("\n");

    source = source.replace(/README\.md/g, `about.html`);
    source = source.replace(/\.md\)/g, `.html)`);

    result = md.render(source);
  }

  template = template.replace("{{content}}", result);

  template = template.replace("{{ubuntu-package}}", getPackage(".deb"));
  template = template.replace("{{fedora-package}}", getPackage(".rpm"));
  template = template.replace(/{{version}}/g, getVersion());

  fs.writeFileSync(destination, template);

  console.log(destination, " created");
}