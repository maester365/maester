import React from "react";

// Renders the small subset of Markdown the attribute rubric uses: paragraphs, bullet and numbered lists,
// tables, inline code, bold and links. The rubric text is generated from
// docs/writing-tests/attribute-rubric.md, so it is shown as written there.

function inline(text, keyPrefix) {
  const out = [];
  const pattern = /(`[^`]+`)|(\*\*[^*]+\*\*)|(\[[^\]]+\]\([^)]+\))/g;
  let last = 0;
  let match;
  let n = 0;
  while ((match = pattern.exec(text)) !== null) {
    if (match.index > last) out.push(text.slice(last, match.index));
    const token = match[0];
    const key = keyPrefix + "-" + n++;
    if (token.startsWith("`")) out.push(<code key={key}>{token.slice(1, -1)}</code>);
    else if (token.startsWith("**")) out.push(<strong key={key}>{inline(token.slice(2, -2), key)}</strong>);
    else {
      const parts = /^\[([^\]]+)\]\(([^)]+)\)$/.exec(token);
      const label = inline(parts[1], key);
      out.push(
        /^https?:/.test(parts[2]) ? (
          <a key={key} href={parts[2]} target="_blank" rel="noreferrer">
            {label}
          </a>
        ) : (
          <span key={key}>{label}</span>
        )
      );
    }
    last = match.index + token.length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

const cells = (line) =>
  line
    .trim()
    .replace(/^\||\|$/g, "")
    .split("|")
    .map((c) => c.trim());

export function parseBlocks(markdown) {
  const blocks = [];
  let current = null;
  const flush = () => {
    if (current) blocks.push(current);
    current = null;
  };
  for (const raw of String(markdown || "").split("\n")) {
    const line = raw.replace(/\s+$/, "");
    if (!line.trim()) {
      flush();
      continue;
    }
    const bullet = /^\s*-\s+(.*)$/.exec(line);
    const numbered = /^\s*\d+\.\s+(.*)$/.exec(line);
    if (line.trim().startsWith("|")) {
      if (!current || current.type !== "table") {
        flush();
        current = { type: "table", rows: [] };
      }
      if (!/^\s*\|[\s:|-]+\|\s*$/.test(line)) current.rows.push(cells(line));
    } else if (bullet || numbered) {
      const type = bullet ? "ul" : "ol";
      if (!current || current.type !== type) {
        flush();
        current = { type, items: [] };
      }
      current.items.push((bullet || numbered)[1]);
    } else if (current && (current.type === "ul" || current.type === "ol") && /^\s+/.test(raw)) {
      current.items[current.items.length - 1] += " " + line.trim();
    } else if (current && current.type === "p") {
      current.text += " " + line.trim();
    } else {
      flush();
      current = { type: "p", text: line.trim() };
    }
  }
  flush();
  return blocks;
}

// The first table of a rubric section as value/meaning pairs, for choice cards.
export function firstTable(markdown) {
  const table = parseBlocks(markdown).find((b) => b.type === "table");
  if (!table) return [];
  return table.rows.slice(1).map((row) => ({ value: row[0].replace(/`/g, ""), text: row[1] }));
}

export default function Markdown({ text }) {
  return (
    <>
      {parseBlocks(text).map((block, i) => {
        if (block.type === "p") return <p key={i}>{inline(block.text, "p" + i)}</p>;
        if (block.type === "ul") return <ul key={i}>{block.items.map((item, j) => <li key={j}>{inline(item, "u" + i + j)}</li>)}</ul>;
        if (block.type === "ol") return <ol key={i}>{block.items.map((item, j) => <li key={j}>{inline(item, "o" + i + j)}</li>)}</ol>;
        return (
          <div key={i} className="table-responsive">
            <table>
              <thead>
                <tr>{block.rows[0].map((c, j) => <th key={j}>{inline(c, "h" + i + j)}</th>)}</tr>
              </thead>
              <tbody>
                {block.rows.slice(1).map((row, r) => (
                  <tr key={r}>{row.map((c, j) => <td key={j}>{inline(c, "c" + i + r + j)}</td>)}</tr>
                ))}
              </tbody>
            </table>
          </div>
        );
      })}
    </>
  );
}
