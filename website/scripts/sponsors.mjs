// Builds the list of people on maester.dev/sponsor: the contributors who have a GitHub Sponsors listing.
//
// Three groups: the core maintainers (`maintainer: true` in website/contributors/contributors.yml), the
// primary authors of tests (the Author of a test's [MaesterTest] attribute, from the contributor snapshot
// at website/src/data/contributors.json) and everyone else who has committed to the repository (GitHub's
// contributors API). Only people with a Sponsors listing are kept; `sponsorPage: false` in contributors.yml
// leaves a person out. The public sponsors of the core maintainers are listed too, to thank them, after the
// featured sponsors kept by hand in website/sponsors/featured.yml, which are shown first with their logos.
//
// Whether a person has a listing is only known to GitHub (GraphQL `hasSponsorsListing`), so this needs a
// token in GH_TOKEN or GITHUB_TOKEN. The .github/workflows/update-sponsors.yaml workflow runs it weekly with
// the maester-bot app and commits the result to website/src/data/sponsors.json, which the site reads at
// build time, and to the Sponsors section of the repository README, which shows the same sponsors. Without a
// token the people of the committed snapshot are kept; the featured sponsors and the README are still updated.
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
const featuredPath = join(websiteRoot, "sponsors", "featured.yml");
const snapshotPath = join(websiteRoot, "src", "data", "sponsors.json");
const readmePath = join(websiteRoot, "..", "README.md");
const repository = "maester365/maester";

const botPattern = /\[bot\]|copilot|github[- ]actions?|actions-user|dependabot|web-flow|snyk/i;

const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;

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

// The featured sponsors, in the order of website/sponsors/featured.yml. A logo without a dark variant is used on
// both backgrounds.
function featuredSponsors() {
  const listed = loadYamlDocument(readFileSync(featuredPath, "utf8")) ?? [];
  return listed.map((sponsor) => {
    for (const field of ["name", "url", "logo"]) {
      if (!sponsor?.[field]) throw new Error(`${featuredPath}: ${sponsor?.name ?? "a sponsor"} has no ${field}.`);
    }
    for (const logo of [sponsor.logo, sponsor.logoDark].filter(Boolean)) {
      if (!existsSync(join(websiteRoot, "static", logo))) throw new Error(`${featuredPath}: no file website/static${logo}.`);
    }
    return {
      name: sponsor.name,
      url: sponsor.url,
      github: sponsor.github ?? "",
      logo: sponsor.logo,
      logoDark: sponsor.logoDark ?? sponsor.logo,
    };
  });
}

// The people on the page, and the public sponsors of the core maintainers, looked up on GitHub.
async function lookUpPeople() {
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
  const people = {
    maintainers: groups.maintainers.map(entry).filter(Boolean).sort(byName),
    testAuthors: groups.testAuthors.map(entry).filter(Boolean).sort((a, b) => b.tests - a.tests || byName(a, b)),
    contributors: groups.contributors.map(entry).filter(Boolean).sort((a, b) => b.commits - a.commits || byName(a, b)),
  };

  // The people and organisations who sponsor a core maintainer: thanked on the page. One entry each, with the
  // maintainers they sponsor; monthly sponsors first, then those who sponsor more maintainers.
  const backers = new Map();
  for (const maintainer of people.maintainers) {
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
  people.backers = [...backers.values()].sort(
    (a, b) => Number(b.monthly) - Number(a.monthly) || b.sponsors.length - a.sponsors.length || byName(a, b)
  );

  console.log(
    `sponsors: ${people.maintainers.length} maintainers, ${people.testAuthors.length} test authors, ` +
      `${people.contributors.length} other contributors with a Sponsors listing (of ${seen.size} people); ` +
      `${people.backers.length} current public sponsors of the maintainers.`
  );
  return people;
}

// The Sponsors section of the repository README, between its sponsors:start and sponsors:end markers: the same
// sponsors as the thank-you on the page. Images have absolute URLs, as the module ships the README too.
const imageBase = `https://raw.githubusercontent.com/${repository}/main/website/static`;
const html = (text) =>
  String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

function readmeSection({ featured, backers }) {
  const lines = [
    "<!-- sponsors:start -->",
    "<!-- Written by website/scripts/sponsors.mjs. To change the featured sponsors, edit website/sponsors/featured.yml. -->",
    "",
    "## Sponsors",
    "",
    "Thank you to the organisations and people who sponsor Maester and its maintainers. You make Maester possible.",
    "",
  ];
  if (featured.length > 0) {
    const logos = featured.map(
      (sponsor) =>
        `<a href="${html(sponsor.url)}"><picture>` +
        `<source media="(prefers-color-scheme: dark)" srcset="${imageBase}${html(sponsor.logoDark)}">` +
        `<img src="${imageBase}${html(sponsor.logo)}" alt="${html(sponsor.name)}" height="52">` +
        `</picture></a>`
    );
    lines.push("<p>", `  ${logos.join("&nbsp;&nbsp;&nbsp;&nbsp;\n  ")}`, "</p>", "");
  }
  if (backers.length > 0) {
    lines.push("<table>");
    for (let i = 0; i < backers.length; i += 6) {
      lines.push("  <tr>");
      for (const backer of backers.slice(i, i + 6)) {
        lines.push(
          `    <td align="center" width="110"><a href="https://github.com/${html(backer.github)}">` +
            `<img src="${html(backer.avatar)}" width="64" height="64" alt=""><br><sub><b>${html(backer.name)}</b></sub></a></td>`
        );
      }
      lines.push("  </tr>");
    }
    lines.push("</table>", "");
  }
  lines.push(
    "Using Maester at work? Ask your company to sponsor one of the [people who build it](https://maester.dev/sponsor).",
    "<!-- sponsors:end -->"
  );
  return lines.join("\n");
}

function writeReadme(snapshot) {
  const readme = readFileSync(readmePath, "utf8");
  const markers = /<!-- sponsors:start -->[\s\S]*?<!-- sponsors:end -->/;
  if (!markers.test(readme)) {
    console.warn("sponsors: README.md has no sponsors:start and sponsors:end markers, leaving it as it is.");
    return;
  }
  writeFileSync(readmePath, readme.replace(markers, () => readmeSection(snapshot)));
}

const featured = featuredSponsors();
const featuredLogins = new Set(featured.map((sponsor) => sponsor.github.toLowerCase()).filter(Boolean));

let people;
if (token) {
  people = await lookUpPeople();
} else {
  console.log("sponsors: no GH_TOKEN or GITHUB_TOKEN, keeping the people of the committed snapshot.");
  people = JSON.parse(readFileSync(snapshotPath, "utf8"));
}

// A featured sponsor who also sponsors a maintainer on GitHub is thanked once, with their logo.
const { backers = [], ...groups } = people;
const snapshot = {
  ...groups,
  featured,
  backers: backers.filter((backer) => !featuredLogins.has(backer.github.toLowerCase())),
};

writeFileSync(snapshotPath, `${JSON.stringify(snapshot, null, 2)}\n`);
writeReadme(snapshot);
console.log(`sponsors: ${snapshot.featured.length} featured sponsors, ${snapshot.backers.length} other sponsors thanked.`);
