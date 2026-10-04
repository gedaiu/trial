import { getCollection, type CollectionEntry } from "astro:content";

/// The first markdown heading of a doc, falling back to its file id
export const docTitle = (entry: CollectionEntry<"docs">) =>
  entry.rendered?.metadata?.headings?.[0]?.text ?? entry.id;

export const allDocs = async () =>
  (await getCollection("docs")).sort((a, b) => docTitle(a).localeCompare(docTitle(b)));
