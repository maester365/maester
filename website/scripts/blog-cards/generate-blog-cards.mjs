// Generates the card image for each blog post (website/blog/<post>/img/card.png, 1200x630) from template.html,
// and points the post's `image` front matter at it, so the /blog grid and social link previews use the same picture.
//
// Each post can set two optional front matter keys; without them the card falls back to the title and tags:
//   card_headline: Maester *3.0*      # short headline for the image; *words* are highlighted
//   card_label: Release               # small label shown on the card (Release, Guide, Event, ...)
//
// Usage (from website/; needs Playwright's Chromium once: npx playwright install chromium):
//   npm run blog-cards                          # posts that don't have a card yet
//   npm run blog-cards -- 2026-10-24-maester-packs   # named posts (folder names), regenerated
//   npm run blog-cards -- --all                 # every post, regenerated

import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { load as loadYaml } from "js-yaml";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const websiteRoot = join(scriptDir, "..", "..");
const blogRoot = join(websiteRoot, "blog");
const cardPath = "./img/card.png";

const args = process.argv.slice(2);
const all = args.includes("--all");
const named = args.filter((a) => !a.startsWith("--"));

const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const emoji = /\p{Extended_Pictographic}️?/gu;

function readPost(folder) {
  const dir = join(blogRoot, folder);
  const file = ["index.md", "index.mdx"].map((f) => join(dir, f)).find(existsSync);
  if (!file) return null;
  const text = readFileSync(file, "utf8");
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return null;
  const frontMatter = loadYaml(match[1]);
  const date = frontMatter.date ? new Date(frontMatter.date).toISOString().slice(0, 10) : folder.slice(0, 10);
  return { dir, file, text, frontMatter, date };
}

function labelFor(tags = []) {
  const t = tags.map((x) => String(x).toLowerCase());
  if (t.includes("release")) return "Release";
  if (t.includes("video")) return "Video";
  return "Blog";
}

function cardData(post) {
  const fm = post.frontMatter;
  return {
    headline: fm.card_headline ?? fm.title.replace(emoji, "").replace(/\s+/g, " ").trim(),
    label: fm.card_label ?? labelFor(fm.tags),
    date: `${Number(post.date.slice(8, 10))} ${months[Number(post.date.slice(5, 7)) - 1]} ${post.date.slice(0, 4)}`,
  };
}

// Point `image` at the card, replacing an existing `image` line or adding one after `tags` (or at the end).
function setImage(post) {
  const [, head] = post.text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  const lines = head.split(/\r?\n/);
  const line = `image: ${cardPath}`;
  const i = lines.findIndex((l) => /^image:/.test(l));
  if (i >= 0) {
    if (lines[i] === line) return;
    lines[i] = line;
  } else {
    const tags = lines.findIndex((l) => /^tags:/.test(l));
    lines.splice(tags >= 0 ? tags + 1 : lines.length, 0, line);
  }
  writeFileSync(post.file, post.text.replace(head, lines.join("\n")));
}

const folders = readdirSync(blogRoot, { withFileTypes: true })
  .filter((d) => d.isDirectory() && /^\d{4}-\d{2}-\d{2}-/.test(d.name))
  .map((d) => d.name)
  .filter((name) => (named.length ? named.includes(name) : all || !existsSync(join(blogRoot, name, "img", "card.png"))));

for (const n of named) if (!folders.includes(n)) console.warn(`No blog post folder named ${n}`);
if (folders.length === 0) {
  console.log("Every post has a card. Use --all or name a post to regenerate.");
  process.exit(0);
}

const { chromium } = await import("playwright");
const template = readFileSync(join(scriptDir, "template.html"), "utf8");
const logo = "data:image/svg+xml;base64," + readFileSync(join(websiteRoot, "static", "img", "logo.svg")).toString("base64");
const browser = await chromium.launch();
try {
  for (const folder of folders) {
    const post = readPost(folder);
    if (!post) continue;
    const card = { ...cardData(post), logo };
    const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
    page.on("pageerror", (e) => console.error(`${folder}: ${e.message}`));
    const html = template.replace("<script>", `<script>window.CARD = ${JSON.stringify(card).replace(/</g, "\\u003c")};`);
    await page.setContent(html, { waitUntil: "networkidle" });
    await page.waitForSelector("body[data-ready]", { state: "attached" });
    mkdirSync(join(post.dir, "img"), { recursive: true });
    await page.screenshot({ path: join(post.dir, "img", "card.png") });
    await page.close();
    setImage(post);
    console.log(`${folder}: ${card.headline}`);
  }
} finally {
  await browser.close();
}
