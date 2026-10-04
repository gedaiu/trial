const isExternal = (url) => /^[a-z]+:/i.test(url);

/// Maps a link between repo markdown files to the matching site page
export const toSitePath = (url) =>
  url.replace(/README\.md/, "about.html").replace(/\.md(#|$)/, ".html$1");

const isBadge = (node) =>
  node.type === "paragraph" &&
  node.children.every((child) => child.type === "link" && child.children[0]?.type === "image"
    || child.type === "text" && child.value.trim() === "");

const visitLinks = (node, rewrite) => {
  if (node.type === "link" && !isExternal(node.url)) {
    node.url = rewrite(node.url);
  }

  node.children?.forEach((child) => visitLinks(child, rewrite));
};

/// Remark plugin: points .md links at .html pages and drops the README badge row
export function rewriteMarkdownLinks() {
  return (tree) => {
    tree.children = tree.children.filter((node) => !isBadge(node));
    visitLinks(tree, toSitePath);
  };
}
