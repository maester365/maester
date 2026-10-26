import React, { useState } from "react";
import Link from "@docusaurus/Link";
// The files the EIDSCA tests are generated from, as committed when the site was built.
import repoConfig from "../../../../build/eidsca/EidscaConfig.json";
import repoMetadata from "../../../../build/eidsca/eidsca-test-metadata.json";
import {
  AREA_FIELDS,
  CHECK_FIELDS,
  MAESTER_FIELDS,
  UPSTREAM_PAGE_URL,
  UPSTREAM_URL,
  diffEidsca,
  formatValue,
  kindLabel,
  mappingRows,
} from "./diff.mjs";
import styles from "./styles.module.css";

const REPO_URL = "https://github.com/maester365/maester/blob/main";

function FieldTable({ fields }) {
  return (
    <div className={styles.tableWrap}>
      <table className={styles.table}>
        <thead>
          <tr>
            <th>EIDSCA field</th>
            <th>Where it goes in Maester</th>
          </tr>
        </thead>
        <tbody>
          {fields.map(({ field, maester }) => (
            <tr key={field}>
              <td>
                <code>{field}</code>
              </td>
              <td>{maester}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function MappingTable() {
  const rows = mappingRows({ repo: repoConfig, metadata: repoMetadata });
  return (
    <div className={styles.tableWrap}>
      <table className={styles.table}>
        <thead>
          <tr>
            <th>Check</th>
            <th>Severity</th>
            <th>Recommended value</th>
            <th>Feature</th>
            <th>Area</th>
            <th>Impact / cost</th>
            <th>Mitre (Maester)</th>
            <th>MitreTechnique (EIDSCA)</th>
            <th>Control</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id}>
              <td>
                {/* A plain link: the page of a check added upstream exists once the test docs are regenerated. */}
                <a href={`/docs/next/tests/${row.id}`}>{row.id}</a>
                <div className={styles.muted}>{row.title}</div>
              </td>
              <td>{row.severity}</td>
              <td>
                <code>{formatValue(row.recommendedValue)}</code>
              </td>
              {row.metadata ? (
                <>
                  <td>{formatValue(row.metadata.Feature)}</td>
                  <td>{formatValue(row.metadata.Area)}</td>
                  <td>
                    {formatValue(row.metadata.UserImpact)} / {formatValue(row.metadata.ImplementationCost)}
                  </td>
                  <td>{formatValue(row.metadata.Mitre)}</td>
                </>
              ) : (
                <td colSpan={4} className={styles.warn}>
                  No row in eidsca-test-metadata.json
                </td>
              )}
              <td>{formatValue(row.upstreamMitre)}</td>
              <td>{row.metadata ? formatValue(row.metadata.Control) : ""}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Value({ value }) {
  return <code className={styles.value}>{formatValue(value)}</code>;
}

function DiffResult({ differences }) {
  if (differences.length === 0) {
    return <p className={styles.ok}>Maester is in sync with the EIDSCA config. There is nothing to do.</p>;
  }
  const kinds = ["new", "removed", "changed", "metadata"];
  return (
    <>
      <p>
        {differences.length} difference(s):{" "}
        {kinds
          .map((kind) => [kind, differences.filter((d) => d.kind === kind).length])
          .filter(([, count]) => count > 0)
          .map(([kind, count]) => `${count} ${kindLabel(kind).toLowerCase()}`)
          .join(", ")}
        .
      </p>
      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Check</th>
              <th>Difference</th>
              <th>Details</th>
              <th>What to do</th>
            </tr>
          </thead>
          <tbody>
            {differences.map((d) => (
              <tr key={`${d.id}-${d.kind}`}>
                <td>
                  {d.id}
                  <div className={styles.muted}>{d.title}</div>
                </td>
                <td>{kindLabel(d.kind)}</td>
                <td>
                  {d.changes
                    ? d.changes.map((c) => (
                        <div key={c.field} className={styles.change}>
                          <strong>{c.field}</strong>
                          <div>
                            Maester: <Value value={c.repo} />
                          </div>
                          <div>
                            EIDSCA: <Value value={c.upstream} />
                          </div>
                        </div>
                      ))
                    : null}
                </td>
                <td>{d.action}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

function LiveCompare() {
  const [state, setState] = useState({ status: "idle" });

  async function compare() {
    setState({ status: "loading" });
    try {
      const response = await fetch(UPSTREAM_URL, { cache: "no-store" });
      if (!response.ok) throw new Error(`The EIDSCA config could not be downloaded (HTTP ${response.status}).`);
      const upstream = JSON.parse((await response.text()).replace(/^﻿/, ""));
      setState({ status: "done", differences: diffEidsca({ upstream, repo: repoConfig, metadata: repoMetadata }) });
    } catch (error) {
      setState({ status: "error", message: error.message });
    }
  }

  return (
    <div className={styles.panel}>
      <p>
        Downloads the EIDSCA config from GitHub in your browser and compares it with the copy and classification this
        site was built from.
      </p>
      <button className="button button--primary" onClick={compare} disabled={state.status === "loading"}>
        {state.status === "loading" ? "Comparing…" : "Compare with EIDSCA now"}
      </button>
      {state.status === "error" && <p className={styles.warn}>{state.message}</p>}
      {state.status === "done" && <DiffResult differences={state.differences} />}
    </div>
  );
}

export default function EidscaSync() {
  return (
    <>
      <section className={styles.section}>
        <h2>How the EIDSCA tests are made</h2>
        <ol>
          <li>
            Thomas Naunheim maintains the checks of the Entra ID Security Config Analyzer in the{" "}
            <Link to={UPSTREAM_PAGE_URL}>EIDSCA config</Link> of the Attack &amp; Defense Playbook repository. It is the
            source of every check: what to read, the recommended value, the severity and the documentation.
          </li>
          <li>
            Maester keeps a copy in <Link to={`${REPO_URL}/build/eidsca/EidscaConfig.json`}>build/eidsca/EidscaConfig.json</Link>,
            so a build needs no network and reproduces the committed tests exactly.
          </li>
          <li>
            The EIDSCA config does not carry the classification every Maester test declares. Maester keeps it in{" "}
            <Link to={`${REPO_URL}/build/eidsca/eidsca-test-metadata.json`}>build/eidsca/eidsca-test-metadata.json</Link>,
            chosen with the <Link to="/docs/next/writing-tests/attribute-rubric">attribute rubric</Link>:{" "}
            {MAESTER_FIELDS.map((f) => (
              <code key={f} className={styles.inline}>
                {f}
              </code>
            ))}
            .
          </li>
          <li>
            <Link to={`${REPO_URL}/build/eidsca/Update-EidscaTests.ps1`}>build/eidsca/Update-EidscaTests.ps1</Link>{" "}
            generates <code>tests/eidsca/Test.EIDSCA.&lt;ID&gt;.ps1</code> and <code>.md</code> and the internal
            functions that read the tenant value, for every check that has a recommended value.
          </li>
          <li>
            Every week, a workflow compares the EIDSCA config with Maester. While they differ, it keeps one issue and one
            pull request with the regenerated tests open, both assigned to the EIDSCA maintainer, and updates them.
            Merging the pull request closes the issue; the next difference starts a new pair.
          </li>
        </ol>
      </section>

      <section className={styles.section}>
        <h2>Compare with EIDSCA</h2>
        <LiveCompare />
      </section>

      <section className={styles.section}>
        <h2>Fields of a check</h2>
        <FieldTable fields={CHECK_FIELDS} />
        <h3>Fields of a control area</h3>
        <FieldTable fields={AREA_FIELDS} />
      </section>

      <section className={styles.section}>
        <h2>The checks in Maester</h2>
        <p>
          Severity and recommended value come from the EIDSCA config; the other columns, except MitreTechnique, are
          Maester's classification.
        </p>
        <MappingTable />
      </section>
    </>
  );
}
