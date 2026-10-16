import React from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";
import TestBuilder from "@site/src/components/TestBuilder";

export default function TestBuilderPage() {
  return (
    <Layout title="Test builder" description="Pick the attributes of a Maester test, with the rubric for each one, and get the code.">
      <main style={{ maxWidth: 1440, margin: "0 auto", padding: "2.5rem 1.25rem 4rem" }}>
        <header style={{ maxWidth: "46rem", marginBottom: "2rem" }}>
          <h1>Test builder</h1>
          <p>
            Every Maester test declares what it is about, how urgent a failure is and what it needs to run, in a <code>[MaesterTest()]</code> attribute. Pick the values here. Each field explains what it means and shows the rule reviewers apply, and the code updates as you go.
          </p>
          <p>
            The lists and rules on this page are generated from the files Maester itself uses, so they match what the unit tests and the review step enforce. The full text is in the <Link to="/docs/next/writing-tests/attribute-rubric">attribute rubric</Link>.
          </p>
        </header>
        <TestBuilder />
      </main>
    </Layout>
  );
}
