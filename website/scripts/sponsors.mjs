// Builds the list of people on maester.dev/sponsor: the contributors who have a GitHub Sponsors listing.
//
// Three groups: the core maintainers (`maintainer: true` in website/contributors/contributors.yml), the
// primary authors of tests (the Author of a test's [MaesterTest] attribute, from the contributor snapshot
// at website/src/data/contributors.json) and everyone else who has committed to the repository (GitHub's
// contributors API). Only people with a Sponsors listing are kept; `sponsorPage: false` in contributors.yml
// leaves a person out. The public sponsors of the core maintainers are listed too, to thank them.
//
// Whether a person has a listing is only known to GitHub (GraphQL `hasSponsorsListing`), so this needs a
// token in GH_TOKEN or GITHUB_TOKEN. The .github/workflows/update-sponsors.yaml workflow runs it weekly with
// the maester-bot app and commits the result to website/src/data/sponsors.json, which the site reads at
// build time. Without a token the committed snapshot is left as it is.
//
// Locally: GH_TOKEN=$(gh auth token) node scripts/sponsors.mjs

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { load as loadYamlDocument } from "js-yaml";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const websiteRoot = join(scriptDir, "..");
const registryPath = join(websiteRoot, "contributors", "contributors.yml");
const contributorsPath = join(websiteRoot, "src", "data", "contributors.json");
const snapshotPath = join(websiteRoot, "src", "data", "sponsors.json");
const repository = "maester365/maester";

const botPattern = /\[bot\]|copilot|github[- ]actions?|actions-user|dependabot|web-flow|snyk/i;

const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
if (!token) {
  console.log("sponsors: no GH_TOKEN or GITHUB_TOKEN, keeping the committed snapshot.");
  process.exit(0);
}

const headers = {
  Authorization: `Bearer ${token}`,
  Accept: "application/vnd.github+json",
  "User-Agent": "maester-website-sponsors",
};

async function github(path) {
  const response = await fetch(`https://api.github.com${path}`, { headers });
  if (!response.ok) throw new Error(`GET ${path}: ${response.status} ${await response.text()}`);
  return response.json();
}

// Everyone who has committed to the repository, most commits first.
async function repositoryContributors() {
  const all = [];
  for (let page = 1; ; page++) {
    const batch = await github(`/repos/${repository}/contributors?per_page=100&page=${page}`);
    all.push(...batch);
    if (batch.length < 100) break;
  }
  return all.filter((c) => c.type === "User" && !botPattern.test(c.login));
}

// The GitHub profile of each login, with whether it has a Sponsors listing: 50 logins to a query, one alias each.
async function sponsorProfiles(logins) {
  const result = new Map();
  for (let i = 0; i < logins.length; i += 50) {
    const batch = logins.slice(i, i + 50);
    const fields = batch
      .map((login, n) => `u${n}: user(login: ${JSON.stringify(login)}) { login name avatarUrl(size: 240) hasSponsorsListing }`)
      .join("\n");
    const response = await fetch("https://api.github.com/graphql", {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({ query: `{ ${fields} }` }),
    });
    if (!response.ok) throw new Error(`GraphQL: ${response.status} ${await response.text()}`);
    const { data, errors } = await response.json();
    // A login that is no longer a user (renamed, deleted) comes back as null with a NOT_FOUND error: skip it.
    const fatal = (errors ?? []).filter((e) => e.type !== "NOT_FOUND");
    if (fatal.length > 0) throw new Error(`GraphQL: ${fatal.map((e) => e.message).join("; ")}`);
    for (const user of Object.values(data ?? {})) {
      if (user) result.set(user.login.toLowerCase(), user);
    }
  }
  return result;
}

// The public sponsors of a maintainer: everyone with a monthly sponsorship that is still running, and anyone
// whose one-time sponsorship was made in the last RECENT_DAYS days. Private sponsorships are never returned for
// another account, so nobody who sponsored privately is named. A token that may not read them leaves the list empty.
const RECENT_DAYS = 90;
async function backersOf(login) {
  const query = `query ($login: String!, $after: String) {
    user(login: $login) {
      sponsorshipsAsMaintainer(first: 100, after: $after, activeOnly: false) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isActive
          isOneTimePayment
          createdAt
          sponsorEntity {
            __typename
            ... on User { login name avatarUrl(size: 120) }
            ... on Organization { login name avatarUrl(size: 120) }
          }
        }
      }
    }
  }`;
  const backers = [];
  try {
    for (let after = null; ; ) {
      const response = await fetch("https://api.github.com/graphql", {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify({ query, variables: { login, after } }),
      });
      if (!response.ok) throw new Error(`${response.status} ${await response.text()}`);
      const { data, errors } = await response.json();
      if (errors?.length) throw new Error(errors.map((e) => e.message).join("; "));
      const page = data?.user?.sponsorshipsAsMaintainer;
      if (!page) break;
      const since = Date.now() - RECENT_DAYS * 24 * 60 * 60 * 1000;
      for (const node of page.nodes) {
        if (!node?.sponsorEntity) continue;
        // A monthly sponsorship that ended has no end date to go by, so it is left out with old one-time ones.
        const current = node.isOneTimePayment ? Date.parse(node.createdAt) >= since : node.isActive;
        if (current) backers.push({ ...node.sponsorEntity, monthly: !node.isOneTimePayment });
      }
      if (!page.pageInfo.hasNextPage) break;
      after = page.pageInfo.endCursor;
    }
  } catch (error) {
    console.warn(`sponsors: could not read the sponsors of ${login}: ${error.message}`);
  }
  return backers;
}

const registry = existsSync(registryPath) ? loadYamlDocument(readFileSync(registryPath, "utf8")) ?? {} : {};
const registryEntries = Object.entries(registry);
const registryFor = (login) => registryEntries.find(([key]) => key.toLowerCase() === login.toLowerCase())?.[1] ?? {};
const { profiles } = JSON.parse(readFileSync(contributorsPath, "utf8"));
const profileFor = (login) => profiles.find((p) => p.github && p.github.toLowerCase() === login.toLowerCase());

const maintainers = registryEntries.filter(([, entry]) => entry?.maintainer === true).map(([login]) => login);
const testAuthors = profiles.filter((p) => p.github && p.testsAuthored.length > 0).map((p) => p.github);
const committers = await repositoryContributors();
const commitsFor = (login) => committers.find((c) => c.login.toLowerCase() === login.toLowerCase())?.contributions ?? 0;

const seen = new Map();
const unique = (logins) =>
  logins.filter((login) => {
    const key = login.toLowerCase();
    if (seen.has(key) || registryFor(login).sponsorPage === false) return false;
    seen.set(key, login);
    return true;
  });
const groups = {
  maintainers: unique(maintainers),
  testAuthors: unique(testAuthors),
  contributors: unique(committers.map((c) => c.login)),
};

const githubUsers = await sponsorProfiles([...seen.values()]);

function entry(login) {
  const user = githubUsers.get(login.toLowerCase());
  if (!user?.hasSponsorsListing) return null;
  const profile = profileFor(user.login);
  const registered = registryFor(user.login);
  return {
    github: user.login,
    name: registered.name || profile?.name || user.name || user.login,
    title: registered.title || profile?.title || "",
    avatar: profile?.avatar?.startsWith("/") ? profile.avatar : user.avatarUrl,
    // A contributor page exists only for people the tests credit.
    contributorPage: profile ? `/contributors/${profile.id.toLowerCase()}` : "",
    tests: profile?.testsAuthored.length ?? 0,
    commits: commitsFor(user.login),
    sponsorUrl: `https://github.com/sponsors/${user.login}`,
  };
}

const byName = (a, b) => a.name.localeCompare(b.name);
const snapshot = {
  maintainers: groups.maintainers.map(entry).filter(Boolean).sort(byName),
  testAuthors: groups.testAuthors.map(entry).filter(Boolean).sort((a, b) => b.tests - a.tests || byName(a, b)),
  contributors: groups.contributors.map(entry).filter(Boolean).sort((a, b) => b.commits - a.commits || byName(a, b)),
};

// The people and organisations who sponsor a core maintainer: thanked on the page. One entry each, with the
// maintainers they sponsor; monthly sponsors first, then those who sponsor more maintainers.
const backers = new Map();
for (const maintainer of snapshot.maintainers) {
  for (const backer of await backersOf(maintainer.github)) {
    const key = backer.login.toLowerCase();
    const known = backers.get(key) ?? {
      github: backer.login,
      name: backer.name || backer.login,
      avatar: backer.avatarUrl,
      organization: backer.__typename === "Organization",
      monthly: false,
      sponsors: [],
    };
    known.monthly ||= backer.monthly;
    if (!known.sponsors.includes(maintainer.github)) known.sponsors.push(maintainer.github);
    backers.set(key, known);
  }
}
snapshot.backers = [...backers.values()].sort(
  (a, b) => Number(b.monthly) - Number(a.monthly) || b.sponsors.length - a.sponsors.length || byName(a, b)
);

writeFileSync(snapshotPath, `${JSON.stringify(snapshot, null, 2)}\n`);
console.log(
  `sponsors: ${snapshot.maintainers.length} maintainers, ${snapshot.testAuthors.length} test authors, ` +
    `${snapshot.contributors.length} other contributors with a Sponsors listing (of ${seen.size} people); ` +
    `${snapshot.backers.length} current public sponsors of the maintainers.`
);
