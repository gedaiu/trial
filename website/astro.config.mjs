import { defineConfig } from "astro/config";
import { rewriteMarkdownLinks } from "./src/lib/rewrite-markdown-links.mjs";

export default defineConfig({
  site: "https://trial.szabobogdan.com",
  build: {
    format: "file",
  },
  markdown: {
    remarkPlugins: [rewriteMarkdownLinks],
  },
});
