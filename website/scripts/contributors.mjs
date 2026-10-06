// Builds contributor attribution for Maester tests.
//
// Per-test attribution comes from the Author and Contributor values of each test's
// [MaesterTest] attribute; tests without them fall back to git history (with
// rename tracking). Git history also supplies profile details, enriched with
// the registry at website/contributors/contributors.yml. Because CI often
// builds from a shallow clone, the computed result is snapshotted to
// website/src/data/contributors.json; when full git history is unavailable the
// committed snapshot is used as-is.

import { execFileSync, execSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { load as loadYamlDocument } from "js-yaml";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const websiteRoot = join(scriptDir, "..");
const repoRoot = join(websiteRoot, "..");
const registryPath = join(websiteRoot, "contributors", "contributors.yml");
const emailAliasesPath = join(websiteRoot, "contributors", "email-aliases.json");
const snapshotPath = join(websiteRoot, "src", "data", "contributors.json");
const avatarDir = join(websiteRoot, "static", "img", "contributors");

const botPattern = /\[bot\]|copilot|github[- ]actions?|actions-user|dependabot|web-flow|snyk/i;
const noreplyPattern = /^(?:\d+\+)?([A-Za-z0-9-]+)@users\.noreply\.github\.com$/i;

function loadYaml(path) {
  if (!existsSync(path)) return {};
  return loadYamlDocument(readFileSync(path, "utf8")) ?? {};
}

function slugify(value) {
  return String(value ?? "unknown")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "unknown";
}

function localAvatarFor(id) {
  for (const ext of ["png", "jpg", "jpeg", "webp"]) {
    if (existsSync(join(avatarDir, `${id}.${ext}`))) return `/img/contributors/${id}.${ext}`;
  }
  return "";
}

// Freeform GitHub locations -> country flag. Country names first, then cities
// that appear without a country. Unknown locations simply get no flag.
const countryPatterns = [
  [/germany|deutschland|koblenz|hamburg|berlin|m[uü]nchen|munich|hann?over|dresden|bielefeld|frankfurt|stuttgart|k[oö]ln|cologne/i, "DE"],
  [/new zealand/i, "NZ"],
  [/netherlands|holland|zwolle|amsterdam|rotterdam|utrecht/i, "NL"],
  [/denmark|copenhagen|aarhus/i, "DK"],
  [/switzerland|z[uü]rich|\bbern\b|basel/i, "CH"],
  [/united states|\busa\b|\bus\b$|texas|ohio|\bnc\b|california|washington|florida|new york/i, "US"],
  [/norway|oslo/i, "NO"],
  [/belgium|brussels|antwerp/i, "BE"],
  [/france|caen|paris|lyon/i, "FR"],
  [/canada|toronto|vancouver|montreal/i, "CA"],
  [/italy|italia|rome|milan/i, "IT"],
  [/australia|brisbane|sydney|melbourne/i, "AU"],
  [/united kingdom|\buk\b|england|scotland|london|manchester/i, "GB"],
  [/sweden|stockholm/i, "SE"],
  [/czech|brno|prague/i, "CZ"],
  [/portugal|lisboa|lisbon|porto/i, "PT"],
  [/singapore/i, "SG"],
  [/austria|vienna|wien/i, "AT"],
  [/finland|helsinki/i, "FI"],
  [/ireland|dublin/i, "IE"],
  [/spain|madrid|barcelona/i, "ES"],
  [/poland|warsaw/i, "PL"],
  [/india/i, "IN"],
  [/japan|tokyo/i, "JP"],
  [/brazil|brasil/i, "BR"],
  [/south africa/i, "ZA"],
];

function flagFor(location) {
  const match = countryPatterns.find(([pattern]) => pattern.test(String(location ?? "")));
  if (!match) return "";
  return [...match[1]].map((ch) => String.fromCodePoint(0x1f1a5 + ch.codePointAt(0))).join("");
}

function initialsFor(name) {
  const parts = String(name ?? "")
    .split(/[\s-]+/)
    .filter((part) => /[a-z0-9]/i.test(part));
  const first = parts[0]?.match(/[a-z0-9]/i)?.[0] ?? "?";
  const last = parts.length > 1 ? parts.at(-1).match(/[a-z0-9]/i)?.[0] ?? "" : "";
  return `${first}${last}`.toUpperCase();
}

// Single pass over the full git history, following renames so that the person
// who moved a file is not credited as its creator.
function loadGitFileHistory() {
  // Uses execFileSync (no shell) so the %x01/%x02-delimited format string reaches
  // git unmodified on every OS. execSync with a shell-quoted string is not
  // portable here: Windows spawns cmd.exe by default, which does not strip the
  // POSIX-style single quotes the format was previously wrapped in, so git would
  // receive literal quote characters and every line would fail to parse.
  const raw = execFileSync(
    "git",
    ["log", "--reverse", "--no-merges", "--name-status", "-M", "--format=%x01%ae%x02%an%x02%aI"],
    { cwd: repoRoot, encoding: "utf8", maxBuffer: 512 * 1024 * 1024 }
  );
  const history = new Map(); // current repo-relative path -> [{ email, name, date }]
  let author = null;
  for (const line of raw.split("\n")) {
    if (line.startsWith("")) {
      const [email, name, date] = line.slice(1).split("");
      author = { email, name, date };
      continue;
    }
    if (!line.trim() || !author) continue;
    const parts = line.split("\t");
    const status = parts[0];
    if (/^R/.test(status) && parts.length >= 3) {
      // Rename: carry history to the new path without crediting the mover.
      const entries = history.get(parts[1]) ?? [];
      history.delete(parts[1]);
      history.set(parts[2], entries);
    } else if (/^[AM]/.test(status) && parts.length >= 2) {
      const entries = history.get(parts[1]) ?? [];
      entries.push(author);
      history.set(parts[1], entries);
    }
  }
  return history;
}

function hasFullGitHistory() {
  try {
    const shallow = execSync("git rev-parse --is-shallow-repository", { cwd: repoRoot, encoding: "utf8" }).trim();
    return shallow !== "true";
  } catch {
    return false;
  }
}

function emailHash(email) {
  return createHash("sha256").update(String(email).trim().toLowerCase()).digest("hex");
}

// Best-effort: ask GitHub which account authored commits with this email.
// Used only for emails not already in the alias cache; skipped silently when
// gh / network / auth is unavailable (the git-name merge still applies).
function lookupGitHubHandle(email) {
  try {
    const handle = execFileSync(
      "gh",
      ["api", `repos/maester365/maester/commits?author=${encodeURIComponent(email)}&per_page=1`, "--jq", ".[0].author.login"],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], timeout: 15000 }
    ).trim();
    return handle && handle !== "null" ? handle : "";
  } catch {
    return "";
  }
}

function buildIdentityResolver(registry, hashedAliases) {
  const emailToId = new Map();
  const canonicalId = new Map(); // lowercased id -> canonical casing
  for (const [id, entry] of Object.entries(registry)) {
    canonicalId.set(id.toLowerCase(), id);
    for (const email of entry?.emails ?? []) emailToId.set(String(email).toLowerCase(), id);
  }

  function canonical(id, isGitHub) {
    const existing = canonicalId.get(id.toLowerCase());
    if (existing) return existing;
    canonicalId.set(id.toLowerCase(), id);
    return id;
  }

  return function resolve(email, name) {
    const raw = String(email ?? "");
    const fromRegistry = emailToId.get(raw.toLowerCase());
    if (fromRegistry) return { id: fromRegistry, github: true };
    const hashed = hashedAliases[emailHash(raw)];
    if (hashed) return { id: hashed, github: true };
    const noreply = raw.match(noreplyPattern);
    if (noreply) return { id: canonical(noreply[1], true), github: true };
    return null; // resolved later by name-merge, or becomes an unlinked identity
  };
}

// Groups raw git identities into contributors. Returns test attributions plus
// aggregate profile data.
export function computeContributorData(tests, { log = console.log, updateAliases = true } = {}) {
  if (!hasFullGitHistory()) {
    if (!existsSync(snapshotPath)) {
      throw new Error(
        "Full git history is unavailable (shallow clone) and no contributors snapshot exists at website/src/data/contributors.json."
      );
    }
    log("Shallow git clone detected - using committed contributors snapshot.");
    return JSON.parse(readFileSync(snapshotPath, "utf8"));
  }

  const registry = loadYaml(registryPath);
  const fileHistory = loadGitFileHistory();
  // Machine-maintained cache: sha256(lowercased email) -> GitHub handle.
  // Never edited by hand - unknown emails are resolved via the GitHub API
  // below and appended automatically.
  const hashedAliases = existsSync(emailAliasesPath) ? JSON.parse(readFileSync(emailAliasesPath, "utf8")) : {};
  const resolve = buildIdentityResolver(registry, hashedAliases);

  // First pass: resolve what we can, remember names for the name-merge pass.
  const nameToIds = new Map(); // lowercased git author name -> Set of resolved ids
  const identities = []; // { email, name, id? }
  const identityByEmail = new Map();
  for (const entries of fileHistory.values()) {
    for (const entry of entries) {
      if (identityByEmail.has(entry.email)) continue;
      if (botPattern.test(entry.email) || botPattern.test(entry.name)) {
        identityByEmail.set(entry.email, { skip: true });
        continue;
      }
      const resolved = resolve(entry.email, entry.name);
      const identity = { email: entry.email, name: entry.name, id: resolved?.id ?? null, github: resolved?.github ?? false };
      identityByEmail.set(entry.email, identity);
      identities.push(identity);
      const nameKey = entry.name.trim().toLowerCase();
      if (!nameToIds.has(nameKey)) nameToIds.set(nameKey, new Set());
      if (identity.id) nameToIds.get(nameKey).add(identity.id);
    }
  }
  // Unknown emails: ask GitHub which account authored those commits, and cache
  // the answer (hashed) so future builds resolve offline.
  let aliasesDirty = false;
  for (const identity of identities) {
    if (identity.id) continue;
    const handle = lookupGitHubHandle(identity.email);
    if (!handle) continue;
    identity.id = handle;
    identity.github = true;
    hashedAliases[emailHash(identity.email)] = handle;
    aliasesDirty = true;
    const nameKey = identity.name.trim().toLowerCase();
    if (!nameToIds.has(nameKey)) nameToIds.set(nameKey, new Set());
    nameToIds.get(nameKey).add(handle);
    log(`Resolved ${identity.name} to @${handle} via the GitHub API.`);
  }
  if (aliasesDirty && updateAliases) {
    const sorted = Object.fromEntries(Object.entries(hashedAliases).sort(([a], [b]) => a.localeCompare(b)));
    writeFileSync(emailAliasesPath, `${JSON.stringify(sorted, null, 2)}\n`);
    log("Updated contributors/email-aliases.json with newly resolved contributors.");
  }

  // Name-merge: an unresolved email whose git author name maps to exactly one
  // known contributor is treated as that contributor.
  for (const identity of identities) {
    if (identity.id) continue;
    const ids = nameToIds.get(identity.name.trim().toLowerCase());
    if (ids?.size === 1) {
      identity.id = [...ids][0];
      identity.github = true;
    } else {
      identity.id = slugify(identity.name);
      identity.github = false;
    }
  }

  // Recent activity: distinct commits touching test/framework files in the
  // last RECENT_DAYS, per contributor (same-commit multi-file edits dedupe on
  // the author timestamp).
  const RECENT_DAYS = 90;
  const cutoffMs = Date.now() - RECENT_DAYS * 24 * 60 * 60 * 1000;
  const recentCommitsById = new Map();
  const seenCommitKeys = new Set();
  for (const [path, entries] of fileHistory) {
    if (!/^(powershell|tests)\//.test(path)) continue;
    for (const entry of entries) {
      if (new Date(entry.date).getTime() < cutoffMs) continue;
      const identity = identityByEmail.get(entry.email);
      if (!identity || identity.skip || !identity.id) continue;
      const key = `${identity.id}|${entry.date}`;
      if (seenCommitKeys.has(key)) continue;
      seenCommitKeys.add(key);
      recentCommitsById.set(identity.id, (recentCommitsById.get(identity.id) ?? 0) + 1);
    }
  }

  // Aggregate contributor info.
  const contributors = new Map(); // id -> profile
  function contributorFor(identity) {
    if (!contributors.has(identity.id)) {
      const entry = registry[identity.id] ?? {};
      contributors.set(identity.id, {
        id: identity.id,
        github: identity.github ? identity.id : "",
        name: entry.name ?? "",
        gitNames: [],
        title: entry.title ?? "",
        mvp: entry.mvp === true || /\bMVP\b/i.test(entry.title ?? ""),
        mvpUrl: entry.mvpUrl ?? "",
        pinLast: entry.pinLast === true,
        company: entry.company ?? "",
        location: entry.location ?? "",
        locationFlag: flagFor(entry.location),
        url: entry.url ?? "",
        socials: entry.socials ?? {},
        avatar: "",
        firstContribution: "",
        testsAuthored: [],
        testsContributed: [],
      });
    }
    const profile = contributors.get(identity.id);
    if (!profile.gitNames.includes(identity.name)) profile.gitNames.push(identity.name);
    return profile;
  }

  // Maester 3.0 native tests declare their credit in the [MaesterTest] attribute (Author, Contributor),
  // seeded once from git and maintained by hand. Those handles are used as-is; git history only
  // supplies profile details (display name, first contribution) for them.
  const canonicalById = new Map(Object.keys(registry).map((id) => [id.toLowerCase(), id]));
  const gitNamesById = new Map(); // lowercased id -> git author names
  const firstDateById = new Map(); // lowercased id -> earliest commit date on test or module files
  for (const identity of identities) {
    if (!identity.id) continue;
    const key = identity.id.toLowerCase();
    if (!canonicalById.has(key)) canonicalById.set(key, identity.id);
    if (!gitNamesById.has(key)) gitNamesById.set(key, []);
    gitNamesById.get(key).push(identity.name);
  }
  for (const [path, entries] of fileHistory) {
    if (!/^(powershell|tests)\//.test(path)) continue;
    for (const entry of entries) {
      const identity = identityByEmail.get(entry.email);
      if (!identity || identity.skip || !identity.id) continue;
      const key = identity.id.toLowerCase();
      if (!firstDateById.has(key) || entry.date < firstDateById.get(key)) firstDateById.set(key, entry.date);
    }
  }
  function declaredContributor(handle) {
    const key = String(handle).toLowerCase();
    const id = canonicalById.get(key) ?? String(handle);
    const profile = contributorFor({ id, name: registry[id]?.name ?? gitNamesById.get(key)?.find((name) => name.includes(" ")) ?? gitNamesById.get(key)?.[0] ?? id, github: true });
    for (const name of gitNamesById.get(key) ?? []) if (!profile.gitNames.includes(name)) profile.gitNames.push(name);
    const firstDate = firstDateById.get(key);
    if (firstDate && (!profile.firstContribution || firstDate < profile.firstContribution)) profile.firstContribution = firstDate;
    return id;
  }

  const attributions = {};
  for (const test of tests) {
    // Credit comes only from the [MaesterTest] attribute (Author, Contributor); every built-in test declares
    // an Author, so a test without one is a metadata error rather than something to guess from git.
    if (!(test.authors?.length > 0)) {
      throw new Error(`Test ${test.id} declares no Author in its [MaesterTest] attribute.`);
    }
    const ids = [];
    for (const handle of [...test.authors, ...(test.contributors ?? [])]) {
      const id = declaredContributor(handle);
      if (!ids.some((existing) => existing.toLowerCase() === id.toLowerCase())) ids.push(id);
    }
    const [author, ...rest] = ids;
    attributions[test.id] = { author, contributors: rest };
    contributors.get(author)?.testsAuthored.push(test.id);
    for (const id of rest) contributors.get(id)?.testsContributed.push(test.id);
  }

  // A profile page, once published, is kept even when no test credits that person any more (the 3.0
  // Contributor rule is stricter than "touched the file"), so links to /contributors/<id> stay valid.
  // Only people with a registry entry are kept, and no new zero-credit pages are created.
  const publishedIds = new Set(
    (existsSync(snapshotPath) ? JSON.parse(readFileSync(snapshotPath, "utf8")).profiles ?? [] : []).map((profile) => String(profile.id).toLowerCase())
  );
  const keptIds = new Set();
  for (const id of Object.keys(registry)) {
    if (!publishedIds.has(id.toLowerCase()) || contributors.has(id)) continue;
    keptIds.add(declaredContributor(id));
  }

  // Finalize profiles: display name, avatar.
  for (const profile of contributors.values()) {
    if (!profile.name) {
      // Prefer a git name that looks like a real name (contains a space).
      profile.name = profile.gitNames.find((name) => name.includes(" ")) ?? profile.gitNames[0] ?? profile.id;
    }
    profile.initials = initialsFor(profile.name);
    profile.firstContribution = profile.firstContribution ? profile.firstContribution.slice(0, 10) : "";
    profile.recentCommits = recentCommitsById.get(profile.id) ?? 0;
    const localAvatar = localAvatarFor(profile.id);
    profile.avatar = localAvatar || (profile.github ? `https://github.com/${profile.github}.png` : "");
    delete profile.gitNames;
  }

  // Rank by a weighted score: authoring a test counts AUTHORED_WEIGHT points.
  // Improvements earn sqrt-dampened points so sustained improvement work still
  // counts, but bulk passes that touch hundreds of files can't swamp the
  // ranking (100 improvements ~= 3 authored tests). Authorship stays the
  // headline signal - it's what we want more of.
  const AUTHORED_WEIGHT = 5;
  const IMPROVEMENT_SCALE = 3;
  const score = (profile) =>
    profile.testsAuthored.length * AUTHORED_WEIGHT +
    Math.sqrt(profile.testsContributed.length) * IMPROVEMENT_SCALE;
  const profiles = [...contributors.values()]
    .filter((profile) => profile.testsAuthored.length + profile.testsContributed.length > 0 || keptIds.has(profile.id))
    .sort(
      (a, b) =>
        (a.pinLast ? 1 : 0) - (b.pinLast ? 1 : 0) ||
        score(b) - score(a) ||
        b.testsAuthored.length - a.testsAuthored.length ||
        a.name.localeCompare(b.name)
    );

  return { profiles, attributions };
}

export { snapshotPath };
