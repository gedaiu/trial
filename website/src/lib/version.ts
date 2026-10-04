import { execSync } from "node:child_process";

const latestTag = () => process.env.CI_COMMIT_TAG
  ?? execSync("git describe --tags --abbrev=0", { encoding: "utf8" }).trim();

export const version = latestTag().replace(/^v/, "");
