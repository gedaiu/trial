import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";

const docs = defineCollection({
  loader: glob({ pattern: "*.md", base: "../doc" }),
});

const readme = defineCollection({
  loader: glob({ pattern: "README.md", base: ".." }),
});

export const collections = { docs, readme };
