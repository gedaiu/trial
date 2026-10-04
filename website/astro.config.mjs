import { defineConfig } from "astro/config";
import { adaptRepoMarkdown } from "./src/lib/adapt-repo-markdown.mjs";

export default defineConfig({
  site: "https://trial.szabobogdan.com",
  build: {
    format: "file",
  },
  markdown: {
    remarkPlugins: [adaptRepoMarkdown],
    shikiConfig: {
      theme: "github-light",
    },
  },
});
