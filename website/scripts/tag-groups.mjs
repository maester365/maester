const tagGroups = [
  ["CIS", (tag) => /^CIS(?:\.|\s|$)/.test(tag) || tag === "L1" || tag === "L2"],
  ["CISA", (tag) => /^CISA(?:\.|$)|^MS\./.test(tag)],
  ["EIDSCA", (tag) => /^EIDSCA(?:\.|$)/.test(tag)],
  ["ORCA", (tag) => /^ORCA(?:\.|$)/.test(tag)],
  ["Maester", (tag) => /^(?:MT\.|Maester)/.test(tag)],
];

export const tagGroupNames = [...tagGroups.map(([name]) => name), "Ungrouped"];

export function tagGroupFor(tag) {
  return tagGroups.find(([, matches]) => matches(tag))?.[0] ?? "Ungrouped";
}
