import React from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";
import communityTestsData from "@site/src/data/community-tests.json";
import styles from "./community-tests.module.css";

function CommunityTestCard({ entry }) {
  const repoUrl = `https://github.com/${entry.repository}`;
  const installCommand = `Install-MtCustomTests -Repository '${entry.repository}'`;

  return (
    <div className={styles.card}>
      <div className={styles.cardHeader}>
        <h3 className={styles.cardName}>{entry.name}</h3>
        {entry.author && (
          <span className={styles.cardAuthor}>
            by{" "}
            {entry.authorUrl ? (
              <a href={entry.authorUrl} target="_blank" rel="noopener noreferrer">
                {entry.author}
              </a>
            ) : (
              entry.author
            )}
          </span>
        )}
      </div>
      <p className={styles.cardDesc}>{entry.description}</p>
      {entry.tags.length > 0 && (
        <div className={styles.cardTags}>
          {entry.tags.map((tag) => (
            <span key={tag} className={styles.tag}>
              {tag}
            </span>
          ))}
        </div>
      )}
      <code className={styles.installCommand}>{installCommand}</code>
      <a className={styles.cardLink} href={repoUrl} target="_blank" rel="noopener noreferrer">
        View on GitHub ↗
      </a>
    </div>
  );
}

export default function CommunityTests() {
  const entries = communityTestsData.entries;

  return (
    <Layout
      title="Community Tests"
      description="Browse community-maintained GitHub repositories that ship custom Maester tests, installable with Install-MtCustomTests."
    >
      <main className={styles.page}>
        <header className={styles.hero}>
          <h1>Community Tests</h1>
          <p>
            Custom Maester tests shared by the community as standalone GitHub repositories.
            Install any of them with one command.
          </p>
        </header>

        <div className={`${styles.disclaimer} alert alert--warning`} role="alert">
          <strong>Maester does not vet, endorse, or guarantee the security of these repositories.</strong>{" "}
          Review the source code yourself before installing, the same way you would before running any
          third-party script. Learn more in the{" "}
          <Link to="/docs/next/writing-tests/creating-custom-tests-repos">custom tests documentation</Link>.
        </div>

        {entries.length > 0 ? (
          <section className={styles.grid}>
            {entries.map((entry) => (
              <CommunityTestCard key={entry.key} entry={entry} />
            ))}
          </section>
        ) : (
          <p className={styles.empty}>No community tests have been listed yet — be the first!</p>
        )}

        <section className={styles.cta}>
          <h2>Share your own tests</h2>
          <p>
            Have a repository with custom Maester tests? Add it to the list by opening a pull request
            against{" "}
            <a
              href="https://github.com/maester365/maester/blob/main/website/community-tests/community-tests.yml"
              target="_blank"
              rel="noopener noreferrer"
            >
              community-tests.yml
            </a>
            . See the{" "}
            <Link to="/docs/next/writing-tests/creating-custom-tests-repos">
              guide to creating a custom tests repository
            </Link>{" "}
            for what your repository needs.
          </p>
        </section>
      </main>
    </Layout>
  );
}
