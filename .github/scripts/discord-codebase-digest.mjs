#!/usr/bin/env node

const API_ROOT = process.env.GITHUB_API_URL || "https://api.github.com";
const REPOSITORY = process.env.GITHUB_REPOSITORY || "maester365/maester";
const DEFAULT_BRANCH = process.env.DIGEST_BRANCH || "main";
const TIME_ZONE = "Australia/Melbourne";
const DISCORD_LIMIT = 1800;
const DISCORD_SUPPRESS_EMBEDS = 1 << 2;

const token = process.env.GITHUB_TOKEN;
const dryRun = parseBoolean(process.env.DIGEST_DRY_RUN ?? process.env.DRY_RUN, false);
const forcePost = parseBoolean(process.env.DIGEST_FORCE_POST ?? process.env.FORCE_POST, false);
const sinceHours = parseSinceHours(process.env.DIGEST_SINCE_HOURS ?? process.env.SINCE_HOURS ?? "24");
const webhookUrl = process.env.DISCORD_CODEBASE_WEBHOOK_URL || process.env.DISCORD_WEBHOOK_URL;
const avatarUrl = process.env.DISCORD_AVATAR_URL;
const now = new Date(process.env.DIGEST_NOW || Date.now());
const mode = process.env.DIGEST_MODE || "daily";

if (!token) {
  fail("GITHUB_TOKEN is required.");
}

const [owner, repo] = REPOSITORY.split("/");

if (!owner || !repo) {
  fail(`GITHUB_REPOSITORY must be owner/repo. Received: ${REPOSITORY}`);
}

if (mode === "monthly-backfill") {
  await runMonthlyBackfill({ owner, repo });
} else if (mode === "daily") {
  await runDailyDigest({ owner, repo });
} else {
  fail(`Unsupported DIGEST_MODE: ${mode}`);
}

async function runDailyDigest({ owner, repo }) {
  if (!dryRun && !forcePost && melbourneHour(now) !== 9) {
    console.log(`Skipping: local time in ${TIME_ZONE} is ${formatMelbourne(now)}, not 9am.`);
    process.exit(0);
  }

  const until = now;
  const since = new Date(until.getTime() - sinceHours * 60 * 60 * 1000);

  console.log(`Building digest for ${REPOSITORY}@${DEFAULT_BRANCH}`);
  console.log(`Window: ${since.toISOString()} to ${until.toISOString()} (${TIME_ZONE})`);
  console.log(`Mode: ${dryRun ? "dry run" : "post"}${forcePost ? " (forced)" : ""}`);

  const commits = await fetchCommits({ owner, repo, branch: DEFAULT_BRANCH, since, until });
  const digest = await buildDigest({ owner, repo, commits });

  if (digest.total === 0) {
    console.log("No qualifying human codebase updates found. Nothing to post.");
    process.exit(0);
  }

  const chunks = buildDiscordChunks(digest, {
    title: "Maester codebase update",
    label: formatMelbourneDate(until),
  });

  await outputDiscordChunks(chunks);
}

async function runMonthlyBackfill({ owner, repo }) {
  const startMonth = parseMonthKey(process.env.DIGEST_BACKFILL_START_MONTH || "2023-11", "DIGEST_BACKFILL_START_MONTH");
  const endMonthValue = process.env.DIGEST_BACKFILL_END_MONTH || currentMonthKey(now);
  const endMonth = parseMonthKey(endMonthValue, "DIGEST_BACKFILL_END_MONTH");
  const months = enumerateMonths(startMonth, endMonth);
  const shouldPrintChunks = parseBoolean(process.env.DIGEST_PRINT_CHUNKS, months.length <= 2);

  if (months.length === 0) {
    fail(`Backfill start month must be before or equal to end month. Received ${startMonth.key} to ${endMonth.key}.`);
  }

  if (!dryRun && process.env.DIGEST_BACKFILL_CONFIRM !== "POST HISTORICAL BACKFILL") {
    fail("Set DIGEST_BACKFILL_CONFIRM='POST HISTORICAL BACKFILL' to post the monthly historical backfill.");
  }

  if (!dryRun && !webhookUrl) {
    fail("DISCORD_CODEBASE_WEBHOOK_URL is required when not running in dry-run mode.");
  }

  console.log(`Building monthly backfill for ${REPOSITORY}@${DEFAULT_BRANCH}`);
  console.log(`Months: ${startMonth.key} to ${endMonth.key}`);
  console.log(`Mode: ${dryRun ? "dry run" : "post"}`);

  let totalUpdates = 0;
  let totalPosts = 0;
  let monthsWithUpdates = 0;

  for (const month of months) {
    const since = monthStart(month);
    const until = nextMonthStart(month);
    const commits = await fetchCommits({ owner, repo, branch: DEFAULT_BRANCH, since, until });
    const digest = await buildDigest({ owner, repo, commits: [...commits].reverse() });

    if (digest.total === 0) {
      console.log(`${month.key}: no qualifying human updates.`);
      continue;
    }

    const chunks = buildDiscordChunks(digest, {
      title: "Maester historical codebase update",
      label: formatMonthLabel(since),
    });

    totalUpdates += digest.total;
    totalPosts += chunks.length;
    monthsWithUpdates += 1;

    console.log(`${month.key}: ${digest.total} update(s), ${chunks.length} Discord post(s).`);

    if (dryRun) {
      if (shouldPrintChunks) {
        for (const [index, chunk] of chunks.entries()) {
          console.log(`\n--- ${month.key} Discord post ${index + 1}/${chunks.length} (${chunk.length} chars) ---\n${chunk}`);
        }
      }
      continue;
    }

    for (const [index, chunk] of chunks.entries()) {
      await postDiscord(chunk);
      console.log(`${month.key}: posted Discord backfill chunk ${index + 1}/${chunks.length}.`);
      await sleep(750);
    }
  }

  console.log(`Backfill complete: ${totalUpdates} update(s) across ${monthsWithUpdates} month(s), ${totalPosts} Discord post(s).`);
}

async function outputDiscordChunks(chunks) {
  if (dryRun) {
    console.log(`Dry run generated ${chunks.length} Discord post(s).`);
    for (const [index, chunk] of chunks.entries()) {
      console.log(`\n--- Discord post ${index + 1}/${chunks.length} (${chunk.length} chars) ---\n${chunk}`);
    }
    return;
  }

  if (!webhookUrl) {
    fail("DISCORD_CODEBASE_WEBHOOK_URL is required when not running in dry-run mode.");
  }

  for (const [index, chunk] of chunks.entries()) {
    await postDiscord(chunk);
    console.log(`Posted Discord digest chunk ${index + 1}/${chunks.length}.`);
  }
}

async function buildDigest({ owner, repo, commits }) {
  const mergedPrs = [];
  const directCommits = [];
  const seenPrs = new Set();

  for (const commit of commits) {
    const title = commitTitle(commit);
    const prNumber = extractPullRequestNumber(title);

    if (isExcludedCommit(commit, title)) {
      continue;
    }

    if (prNumber) {
      const pr = await fetchPullRequest({ owner, repo, number: prNumber });
      if (pr && isMergedToBranch(pr, DEFAULT_BRANCH) && !isExcludedPullRequest(pr)) {
        if (!seenPrs.has(pr.number)) {
          seenPrs.add(pr.number);
          mergedPrs.push({
            number: pr.number,
            title: sanitizeTitle(pr.title),
            url: pr.html_url,
            commitSha: commit.sha,
            commitUrl: commit.html_url,
            contributor: contributorFromPullRequest(pr),
          });
        }
        continue;
      }
    }

    directCommits.push({
      title: sanitizeTitle(title),
      sha: commit.sha,
      url: commit.html_url,
      contributor: contributorFromCommit(commit),
    });
  }

  return {
    mergedPrs,
    directCommits,
    total: mergedPrs.length + directCommits.length,
  };
}

async function fetchCommits({ owner, repo, branch, since, until }) {
  const all = [];

  for (let page = 1; page <= 10; page++) {
    const params = new URLSearchParams({
      sha: branch,
      since: since.toISOString(),
      until: until.toISOString(),
      per_page: "100",
      page: String(page),
    });

    const pageItems = await githubJson(`/repos/${owner}/${repo}/commits?${params}`);
    all.push(...pageItems);

    if (pageItems.length < 100) {
      break;
    }
  }

  return all;
}

async function fetchPullRequest({ owner, repo, number }) {
  try {
    return await githubJson(`/repos/${owner}/${repo}/pulls/${number}`);
  } catch (error) {
    console.warn(`Warning: could not fetch PR #${number}: ${error.message}`);
    return null;
  }
}

async function githubJson(path) {
  const response = await fetch(`${API_ROOT}${path}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "maester-discord-codebase-digest",
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`GitHub API ${path} failed (${response.status}): ${body}`);
  }

  return response.json();
}

async function postDiscord(content) {
  const payload = {
    username: "Maester bot",
    content,
    allowed_mentions: { parse: [] },
    flags: DISCORD_SUPPRESS_EMBEDS,
  };

  if (avatarUrl) {
    payload.avatar_url = avatarUrl;
  }

  for (let attempt = 1; attempt <= 5; attempt++) {
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (response.status === 429) {
      const rateLimit = await response.json().catch(() => ({ retry_after: 1 }));
      const delayMs = Math.ceil((rateLimit.retry_after ?? 1) * 1000);
      await sleep(delayMs);
      continue;
    }

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Discord webhook failed (${response.status}): ${body}`);
    }

    return;
  }

  throw new Error("Discord webhook failed after retrying rate limits.");
}

function buildDiscordChunks(digest, { title, label }) {
  const entries = [];

  entries.push({ text: `_${label}_` });
  entries.push({ text: "" });

  if (digest.mergedPrs.length > 0) {
    entries.push({ text: "**Merged PRs**", section: "Merged PRs", heading: true });
    for (const pr of digest.mergedPrs) {
      entries.push({
        text: `- [\`${shortSha(pr.commitSha)}\`](${pr.commitUrl}) ${truncate(pr.title)} by ${formatContributor(pr.contributor)} ([#${pr.number}](${pr.url}))`,
        section: "Merged PRs",
      });
    }
    entries.push({ text: "" });
  }

  if (digest.directCommits.length > 0) {
    entries.push({ text: "**Direct commits**", section: "Direct commits", heading: true });
    for (const commit of digest.directCommits) {
      entries.push({
        text: `- [\`${shortSha(commit.sha)}\`](${commit.url}) ${truncate(commit.title)} by ${formatContributor(commit.contributor)}`,
        section: "Direct commits",
      });
    }
  }

  return splitPosts(entries, title);
}

function splitPosts(entries, title) {
  let chunks = splitWithHeader(entries, (page, total) => header(title, page, total));
  let previousCount = 0;

  while (chunks.length !== previousCount) {
    previousCount = chunks.length;
    chunks = splitWithHeader(entries, (page) => header(title, page, previousCount));
  }

  return chunks;
}

function splitWithHeader(entries, makeHeader) {
  const chunks = [];
  let page = 1;
  let current = makeHeader(page, 1);
  let currentSection = null;

  for (const entry of entries) {
    const line = entry.text.length > DISCORD_LIMIT / 2 ? truncate(entry.text, 900) : entry.text;
    const candidate = `${current}\n${line}`;

    if (candidate.length > DISCORD_LIMIT && current !== makeHeader(page, 1)) {
      chunks.push(current.trimEnd());
      page += 1;
      current = makeHeader(page, 1);
      if (entry.section && !entry.heading && entry.section === currentSection) {
        current = `${current}\n**${entry.section} continued**`;
      }
      current = `${current}\n${line}`;
    } else {
      current = candidate;
    }

    if (entry.section) {
      currentSection = entry.section;
    }
  }

  chunks.push(current.trimEnd());
  return chunks;
}

function header(title, page, total) {
  if (total > 1) {
    return `**${title} (${page}/${total})**`;
  }

  return `**${title}**`;
}

function extractPullRequestNumber(title) {
  const squashMatch = title.match(/\(#(\d+)\)\s*$/);
  if (squashMatch) {
    return Number(squashMatch[1]);
  }

  const mergeMatch = title.match(/^Merge pull request #(\d+)\b/);
  if (mergeMatch) {
    return Number(mergeMatch[1]);
  }

  return null;
}

function isMergedToBranch(pr, branch) {
  return pr.merged_at && pr.base?.ref === branch;
}

function isExcludedCommit(commit, title) {
  return isBotAccount(commit.author)
    || isBotAccount(commit.committer)
    || isBotName(commit.commit?.author?.name)
    || isBotName(commit.commit?.committer?.name)
    || isDependencyUpdate(title);
}

function isExcludedPullRequest(pr) {
  return isBotAccount(pr.user) || isDependencyUpdate(pr.title);
}

function isBotAccount(account) {
  return isBotLogin(account?.login) || account?.type === "Bot";
}

function isBotLogin(login) {
  if (!login) {
    return false;
  }

  return login.endsWith("[bot]")
    || login === "dependabot"
    || login === "dependabot-preview"
    || login === "github-actions";
}

function isBotName(name) {
  if (!name) {
    return false;
  }

  return /\[bot\]/i.test(name) || /dependabot/i.test(name) || /github-actions/i.test(name);
}

function isDependencyUpdate(title) {
  return /^chore\(deps\):\s*bump\b/i.test(title)
    || /^build\(deps\):\s*bump\b/i.test(title)
    || /^deps:\s*bump\b/i.test(title)
    || /\bbump\b.+\bfrom\b.+\bto\b/i.test(title);
}

function contributorFromPullRequest(pr) {
  if (pr.user?.login) {
    return {
      name: pr.user.login,
      url: pr.user.html_url || `https://github.com/${pr.user.login}`,
    };
  }

  return { name: "unknown" };
}

function contributorFromCommit(commit) {
  if (commit.author?.login) {
    return {
      name: commit.author.login,
      url: commit.author.html_url || `https://github.com/${commit.author.login}`,
    };
  }

  return {
    name: sanitizeTitle(commit.commit?.author?.name || "unknown"),
  };
}

function formatContributor(contributor) {
  if (!contributor?.name) {
    return "unknown";
  }

  const name = escapeMarkdown(contributor.name);
  if (contributor.url) {
    return `[${name}](${contributor.url})`;
  }

  return name;
}

function commitTitle(commit) {
  return sanitizeTitle(commit.commit?.message?.split("\n")[0] || commit.sha);
}

function sanitizeTitle(value) {
  return String(value)
    .replace(/[\r\n]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function escapeMarkdown(value) {
  return String(value).replace(/([\\`*_{}[\]()#+.!|-])/g, "\\$1");
}

function truncate(value, maxLength = 240) {
  if (value.length <= maxLength) {
    return value;
  }

  return `${value.slice(0, maxLength - 1).trimEnd()}...`;
}

function shortSha(sha) {
  return sha.slice(0, 7);
}

function parseBoolean(value, defaultValue) {
  if (value === undefined || value === null || value === "") {
    return defaultValue;
  }

  return ["1", "true", "yes", "on"].includes(String(value).toLowerCase());
}

function parseSinceHours(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    fail(`since_hours must be a positive number. Received: ${value}`);
  }

  return parsed;
}

function parseMonthKey(value, name) {
  const match = String(value).match(/^(\d{4})-(\d{2})$/);
  if (!match) {
    fail(`${name} must use YYYY-MM format. Received: ${value}`);
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  if (month < 1 || month > 12) {
    fail(`${name} month must be between 01 and 12. Received: ${value}`);
  }

  return {
    year,
    month,
    key: `${match[1]}-${match[2]}`,
  };
}

function enumerateMonths(start, end) {
  const months = [];
  let year = start.year;
  let month = start.month;

  while (year < end.year || (year === end.year && month <= end.month)) {
    months.push({ year, month, key: `${year}-${String(month).padStart(2, "0")}` });
    month += 1;
    if (month > 12) {
      year += 1;
      month = 1;
    }
  }

  return months;
}

function monthStart(month) {
  return new Date(Date.UTC(month.year, month.month - 1, 1, 0, 0, 0));
}

function nextMonthStart(month) {
  return month.month === 12
    ? new Date(Date.UTC(month.year + 1, 0, 1, 0, 0, 0))
    : new Date(Date.UTC(month.year, month.month, 1, 0, 0, 0));
}

function currentMonthKey(date) {
  const parts = new Intl.DateTimeFormat("en-AU", {
    timeZone: TIME_ZONE,
    year: "numeric",
    month: "2-digit",
  }).formatToParts(date);

  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  return `${year}-${month}`;
}

function melbourneHour(date) {
  const parts = new Intl.DateTimeFormat("en-AU", {
    timeZone: TIME_ZONE,
    hour: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);

  return Number(parts.find((part) => part.type === "hour")?.value);
}

function formatMelbourne(date) {
  return new Intl.DateTimeFormat("en-AU", {
    timeZone: TIME_ZONE,
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function formatMelbourneDate(date) {
  return new Intl.DateTimeFormat("en-AU", {
    timeZone: TIME_ZONE,
    dateStyle: "medium",
  }).format(date);
}

function formatMonthLabel(date) {
  return new Intl.DateTimeFormat("en-AU", {
    timeZone: TIME_ZONE,
    month: "long",
    year: "numeric",
  }).format(date);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
