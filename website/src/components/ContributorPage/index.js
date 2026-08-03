import React from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";
import contributorData from "@site/src/data/contributors.json";
import { MvpBadge, SocialLinks } from "@site/src/pages/contributors";
import styles from "./styles.module.css";

function TestList({ title, testIds }) {
  if (testIds.length === 0) return null;
  return (
    <section className={styles.section}>
      <h2>{title}</h2>
      <ul className={styles.testList}>
        {testIds.map((id) => (
          <li key={id}>
            <Link to={contributorData.tests?.[id]?.path ?? `/docs/tests/${id}`}>
              <span className={styles.testId}>{id}</span>
              <span className={styles.testTitle}>{contributorData.tests?.[id]?.title ?? ""}</span>
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}

export default function ContributorPage({ contributorId }) {
  const profile = contributorData.profiles.find((candidate) => candidate.id === contributorId);
  if (!profile) {
    return (
      <Layout title="Contributor">
        <main className={styles.page}>
          <p>
            Contributor not found. <Link to="/contributors">Back to all contributors</Link>
          </p>
        </main>
      </Layout>
    );
  }

  const profileHref = profile.github ? `https://github.com/${profile.github}` : profile.url;
  return (
    <Layout
      title={`${profile.name} - Maester Contributor`}
      description={`Maester tests authored and improved by ${profile.name}.`}
    >
      <main className={styles.page}>
        <header className={styles.header}>
          {profile.avatar ? (
            <img className={styles.avatar} src={profile.avatar} alt={profile.name} />
          ) : (
            <div className={`${styles.avatar} ${styles.avatarFallback}`}>{profile.initials}</div>
          )}
          <div>
            <h1>
              {profileHref ? <a href={profileHref} target="_blank" rel="noopener noreferrer">{profile.name}</a> : profile.name}
              {profile.mvp && <MvpBadge profile={profile} className={styles.mvpBadge} />}
            </h1>
            {profile.title && <p className={styles.headline}>{profile.title}</p>}
            {(profile.company || profile.location) && (
              <p className={styles.place}>
                {profile.company && <span>🏢 {profile.company}</span>}
                {profile.location && <span>{profile.locationFlag || "📍"} {profile.location}</span>}
              </p>
            )}
            <p className={styles.meta}>
              {profile.testsAuthored.length > 0 && (
                <span>✍️ {profile.testsAuthored.length} {profile.testsAuthored.length === 1 ? "test" : "tests"} authored</span>
              )}
              {profile.github && (
                <a href={`https://github.com/maester365/maester/commits?author=${profile.github}`} target="_blank" rel="noopener noreferrer">
                  🤝 {profile.testsContributed.length > 0 ? `${profile.testsContributed.length} ` : ""}improvements
                </a>
              )}
              <Link to="/contributors">All contributors →</Link>
            </p>
            <SocialLinks profile={profile} className={styles.socials} />
          </div>
        </header>
        <TestList title="Tests authored" testIds={profile.testsAuthored} />
        <TestList title="Also contributed to" testIds={profile.testsContributed} />
      </main>
    </Layout>
  );
}
