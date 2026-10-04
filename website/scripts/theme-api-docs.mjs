import { cpSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [ddoxDir, outDir] = process.argv.slice(2);

const head = '<link rel="stylesheet" href="/assets/site.css"></head>';
const nav = readFileSync(new URL("../src/partials/nav.html", import.meta.url), "utf8");

/// Wraps a ddox page in the site nav and typography
export const themePage = (html) => html
  .replace("</head>", head)
  .replace(/<body([^>]*)>/, `<body$1>${nav}<div class="container-docs">`)
  .replace("</body>", "</div></body>");

cpSync(ddoxDir, outDir, { recursive: true });
cpSync(new URL("../ddox.css", import.meta.url), join(outDir, "styles/ddox.css"));

readdirSync(outDir, { recursive: true })
  .filter((file) => file.endsWith(".html"))
  .map((file) => join(outDir, file))
  .forEach((file) => writeFileSync(file, themePage(readFileSync(file, "utf8"))));
