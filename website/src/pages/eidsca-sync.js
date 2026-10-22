import React from "react";
import Layout from "@theme/Layout";
import EidscaSync from "@site/src/components/EidscaSync";

export default function EidscaSyncPage() {
  return (
    <Layout
      title="EIDSCA sync"
      description="How the Maester EIDSCA tests are generated from the Entra ID Security Config Analyzer, and a live comparison with it."
    >
      <main style={{ maxWidth: 1440, margin: "0 auto", padding: "2.5rem 1.25rem 4rem" }}>
        <header style={{ maxWidth: "46rem", marginBottom: "2rem" }}>
          <h1>EIDSCA sync</h1>
          <p>
            The EIDSCA tests in Maester are generated from the Entra ID Security Config Analyzer (EIDSCA). This page
            shows which values come from EIDSCA and which Maester adds, and compares Maester with the latest EIDSCA
            config.
          </p>
        </header>
        <EidscaSync />
      </main>
    </Layout>
  );
}
