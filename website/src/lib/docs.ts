import { getCollection, type CollectionEntry } from "astro:content";

type Doc = CollectionEntry<"docs">;

const readingOrder = [
  "getting-started",
  "command-line",
  "test-discovery",
  "executors",
  "reporters",
  "steps",
  "attributes",
  "attachments",
  "plugins",
];

/// The first markdown heading of a doc, falling back to its file id
export const docTitle = (entry: Doc) =>
  entry.rendered?.metadata?.headings?.[0]?.text ?? entry.id;

/// The first prose line of a markdown file, skipping headings, links and lists
export const firstSentence = (markdown: string) =>
  markdown
    .split("\n")
    .map((line) => line.trim())
    .find((line) => /^[A-Za-z`]/.test(line)) ?? "";

/// The h2 headings of a rendered page, for the "on this page" outline
export const outline = (entry: { rendered?: Doc["rendered"] }) =>
  (entry.rendered?.metadata?.headings ?? []).filter((heading) => heading.depth === 2);

const position = (entry: Doc) => {
  const index = readingOrder.indexOf(entry.id);
  return index === -1 ? readingOrder.length : index;
};

export const allDocs = async () =>
  (await getCollection("docs")).sort((a, b) => position(a) - position(b) || docTitle(a).localeCompare(docTitle(b)));
