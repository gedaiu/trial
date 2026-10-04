const isExternal = (url) => /^[a-z]+:/i.test(url);

/// Maps a link between repo markdown files to the matching site page
export const toSitePath = (url) =>
  url.replace(/README\.md/, "about.html").replace(/\.md(#|$)/, ".html$1");

const isBlank = (node) => node.type === "text" && node.value.trim() === "";

const isBadgeRow = (node) =>
  node.type === "paragraph" &&
  node.children.every((child) => child.type === "link" && child.children[0]?.type === "image" || isBlank(child));

const isUpLink = (node) =>
  node.type === "paragraph" &&
  node.children.length === 1 &&
  node.children[0].type === "link" &&
  node.children[0].url.endsWith("README.md");

const isSummaryHeading = (node) =>
  node.type === "heading" && node.children[0]?.value === "Summary";

/// Drops the blocks that only help when reading the docs on GitLab: badges, the "up" link and the Summary list
export const withoutRepoNavigation = (nodes) =>
  nodes.filter((node, index) =>
    !isBadgeRow(node) &&
    !isUpLink(node) &&
    !isSummaryHeading(node) &&
    !(node.type === "list" && isSummaryHeading(nodes[index - 1] ?? {})));

const visitLinks = (node, rewrite) => {
  if (node.type === "link" && !isExternal(node.url)) {
    node.url = rewrite(node.url);
  }

  node.children?.forEach((child) => visitLinks(child, rewrite));
};

/// Remark plugin: turns a repo markdown file into a site page
export function adaptRepoMarkdown() {
  return (tree) => {
    tree.children = withoutRepoNavigation(tree.children);
    visitLinks(tree, toSitePath);
  };
}
