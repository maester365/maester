// Writes the sample run that the report's dev server shows, for website/scripts/build-demo-report.mjs: the sample
// result with what a real run adds (affected objects, earlier runs, the Zero Trust Assessment pack's menu and guide),
// and the Zero Trust plan that the pack attaches. The dev server builds both from src/lib/sampleExtras.ts and
// src/lib/sampleZeroTrust.ts; this script loads those same files through Vite, so the demo matches what you see there.
//
// Usage (from report/):  node scripts/export-demo-data.mjs <output folder>
// It writes <folder>/results.json and <folder>/zero-trust-workshop.json.
import { mkdirSync, writeFileSync } from "node:fs"
import { join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { createServer } from "vite"

const out = resolve(process.argv[2] ?? "")
if (!process.argv[2]) {
  console.error("Usage: node scripts/export-demo-data.mjs <output folder>")
  process.exit(1)
}
const root = fileURLToPath(new URL("..", import.meta.url))

const server = await createServer({ root, server: { middlewareMode: true }, appType: "custom", logLevel: "error" })
try {
  const { testResults } = await server.ssrLoadModule("/src/lib/testResults.ts")
  const { withSampleExtras } = await server.ssrLoadModule("/src/lib/sampleExtras.ts")
  const { sampleWorkshop } = await server.ssrLoadModule("/src/lib/sampleZeroTrust.ts")
  const results = withSampleExtras(testResults)
  // The dev server names its plan "dev:…" and builds it on load; a built report carries it as an attachment.
  results.Attachments = (results.Attachments ?? []).filter((a) => !String(a?.Id).startsWith("dev:"))
  mkdirSync(out, { recursive: true })
  writeFileSync(join(out, "results.json"), JSON.stringify(results))
  writeFileSync(join(out, "zero-trust-workshop.json"), JSON.stringify(await sampleWorkshop()))
  console.log(`Wrote ${join(out, "results.json")} and ${join(out, "zero-trust-workshop.json")}.`)
} finally {
  await server.close()
}
