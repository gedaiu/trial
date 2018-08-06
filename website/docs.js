const fs = require("fs");
const fse = require('fs-extra')
const path = require("path");
const MarkdownIt = require('markdown-it');

const menu = fs.readFileSync("template/_apiMenu.html").toString();
const bootstrapCss = '<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0/css/bootstrap.min.css" integrity="sha384-Gn5384xqQ1aoWXA+058RXPxPg6fy4IWvTNh0E263XmFcJlSAwiGgFAW/dAiS6JXm" crossorigin="anonymous">'
const bootstrapJs = `<script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.12.9/umd/popper.min.js" integrity="sha384-ApNbgh9B+Y1QKtv3Rn7W3mgPxhU9K/ScQsAP7hUibX39j7fakFPskvXusvfa0b4Q"
crossorigin="anonymous"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0/js/bootstrap.min.js" integrity="sha384-JZR6Spejh4U02d8jOt6vLEHfe/JQGiRRSQQxSfFWpi1MquVdAyjUar5+76PVCmYl"
crossorigin="anonymous"></script>
<script src="{{root}}assets/script.js"></script>`;

///
function getFiles(dir) {
  return fs.readdirSync(dir)
    .reduce((files, file) =>
      fs.statSync(path.join(dir, file)).isDirectory() ?
        files.concat(getFiles(path.join(dir, file))) :
        files.concat(path.join(dir, file)),
      []);
}

function addMenu(file) {
  var pieces = file.split("/");
  var root = pieces.map(a => "..").splice(0, pieces.length-2).join("/") + "/";

  var result = fs.readFileSync(file)
    .toString()
    .replace('</head>', bootstrapCss + '</head>')
    .replace('</body>', '</div>' + bootstrapJs + '</body>')
    .replace('<body onload="setupDdox();">', '<body onload="setupDdox();">' + menu + '<div class="container-docs">')
    .replace(/{{root}}/g, root);

  fs.writeFileSync(file, result);
}

var allFiles = getFiles("../docs").filter(a => a.endsWith(".html"));

allFiles.forEach(file => {
  addMenu(file);
});