// Reads the step catalogue of the defender's path (powershell/assets/steps: goals.json and one <product>.json per
// product) and the measure registry (powershell/assets/MaesterMeasures.psd1), for the goal pages
// (generate-goal-pages.mjs) and the test pages (generate-test-docs.mjs). The module's own reader is
// Get-MtStepCatalog; this one follows the same rules for a goal's steps: the goal's step and its prerequisites at
// any depth, through Requires, RequiresOneOf and RecommendedFirst, prerequisites first.
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// The repository root. A page bundled by Astro runs from another folder, so it passes the root itself.
const defaultRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");

// The URL of a goal's page, and of a step on it.
export const goalPath = (goalId) => `/docs/defenders-path/${goalId}`;
export const stepAnchor = (stepId) => stepId.replace(/\./g, "-");

// Key, Title, Unit and Caveat of each measure. The registry is a PowerShell data file with one hashtable per
// measure and one quoted string per key, so a line-based read is enough here.
function loadMeasures(measuresPath) {
  const measures = new Map();
  if (!existsSync(measuresPath)) return measures;
  const text = readFileSync(measuresPath, "utf8").replace(/^\s*#.*$/gm, "");
  for (const block of text.split(/@\{/).slice(1)) {
    const field = (name) => {
      const match = block.match(new RegExp(`^\\s*${name}\\s*=\\s*(?:'((?:[^']|'')*)'|"([^"]*)")`, "m"));
      if (!match) return "";
      return match[1] !== undefined ? match[1].replace(/''/g, "'") : match[2];
    };
    const key = field("Key");
    if (key) measures.set(key, { key, title: field("Title"), unit: field("Unit"), caveat: field("Caveat") });
  }
  return measures;
}

export function loadStepCatalog(repoRoot = defaultRoot) {
  const stepsRoot = join(repoRoot, "powershell", "assets", "steps");
  const steps = new Map();
  let goals = [];
  for (const name of readdirSync(stepsRoot).filter((n) => n.endsWith(".json")).sort()) {
    const data = JSON.parse(readFileSync(join(stepsRoot, name), "utf8"));
    if (name === "goals.json") goals = data.Goals ?? [];
    for (const step of data.Steps ?? []) {
      steps.set(step.Id, {
        ...step,
        Product: data.Product,
        Requires: step.Requires ?? [],
        RequiresOneOf: step.RequiresOneOf ?? [],
        RecommendedFirst: step.RecommendedFirst ?? [],
        Conflicts: step.Conflicts ?? [],
        OnlyWhen: step.OnlyWhen ?? [],
        Rollout: step.Rollout ?? [],
        Sources: step.Sources ?? [],
      });
    }
  }

  const edges = (id) => {
    const step = steps.get(id);
    if (!step) return [];
    return [...new Set([...step.Requires, ...step.RequiresOneOf.flat(), ...step.RecommendedFirst])].filter((other) => other !== id && steps.has(other));
  };
  for (const goal of goals) {
    const order = [];
    const seen = new Set();
    const walk = (id) => {
      if (seen.has(id) || !steps.has(id)) return;
      seen.add(id);
      for (const next of edges(id)) walk(next);
      order.push(id);
    };
    walk(goal.Step);
    goal.Steps = order;
  }

  // The goals each step belongs to, and the page a link to the step goes to: the goal it achieves, else the first
  // goal it is part of.
  for (const step of steps.values()) {
    step.Goals = goals.filter((goal) => goal.Steps.includes(step.Id)).map((goal) => goal.Id);
    step.Home = goals.find((goal) => goal.Step === step.Id)?.Id ?? step.Goals[0] ?? null;
  }

  return { steps, goals, measures: loadMeasures(join(repoRoot, "powershell", "assets", "MaesterMeasures.psd1")) };
}

export const stepUrl = (step, goalId) => (goalId ?? step.Home ? `${goalPath(goalId ?? step.Home)}#${stepAnchor(step.Id)}` : "");
