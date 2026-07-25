import React from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";
import contributorData from "@site/src/data/contributors.json";
import styles from "./contributors.module.css";

const socialIcons = {
  github: (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
    </svg>
  ),
  x: (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
    </svg>
  ),
  linkedin: (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 1 1 0-4.124 2.062 2.062 0 0 1 0 4.124zM7.119 20.452H3.555V9h3.564v11.452z" />
    </svg>
  ),
  bluesky: (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 10.8c-1.087-2.114-4.046-6.053-6.798-7.995C2.566.944 1.561 1.266.902 1.565.139 1.908 0 3.08 0 3.768c0 .69.378 5.65.624 6.479.815 2.736 3.713 3.66 6.383 3.364-3.913.58-7.387 2.005-2.83 7.078 5.013 5.19 6.87-1.113 7.823-4.308.953 3.195 2.05 9.271 7.733 4.308 4.267-4.308 1.172-6.498-2.74-7.078 2.67.297 5.568-.628 6.383-3.364.246-.828.624-5.79.624-6.478 0-.69-.139-1.861-.902-2.206-.659-.298-1.664-.62-4.3 1.24C16.046 4.748 13.087 8.687 12 10.8z" />
    </svg>
  ),
  website: (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm7.93 9h-3.47a15.7 15.7 0 0 0-1.4-6.07A8.02 8.02 0 0 1 19.93 11zM12 4.04c.83 1.2 1.94 3.56 2.22 6.96H9.78c.28-3.4 1.39-5.76 2.22-6.96zM4.07 13h3.47c.14 2.34.63 4.44 1.4 6.07A8.02 8.02 0 0 1 4.07 13zm3.47-2H4.07a8.02 8.02 0 0 1 4.87-6.07A15.7 15.7 0 0 0 7.54 11zM12 19.96c-.83-1.2-1.94-3.56-2.22-6.96h4.44c-.28 3.4-1.39 5.76-2.22 6.96zm3.06-.89c.77-1.63 1.26-3.73 1.4-6.07h3.47a8.02 8.02 0 0 1-4.87 6.07z" />
    </svg>
  ),
};

function socialLinks(profile) {
  const links = [];
  if (profile.github) links.push({ type: "github", label: "GitHub", href: `https://github.com/${profile.github}` });
  if (profile.socials?.x) links.push({ type: "x", label: "X", href: `https://x.com/${profile.socials.x}` });
  if (profile.socials?.linkedin) links.push({ type: "linkedin", label: "LinkedIn", href: `https://www.linkedin.com/in/${profile.socials.linkedin}` });
  if (profile.socials?.bluesky) links.push({ type: "bluesky", label: "Bluesky", href: `https://bsky.app/profile/${profile.socials.bluesky}` });
  if (profile.url) links.push({ type: "website", label: "Website", href: profile.url });
  return links;
}

export function MvpBadge({ profile, className }) {
  const img = (
    <img
      src="/img/mvp-badge.png"
      alt="Microsoft Most Valuable Professional"
      title="Microsoft Most Valuable Professional"
      loading="lazy"
    />
  );
  if (!profile.mvpUrl) return <span className={className}>{img}</span>;
  return (
    <a
      className={className}
      href={profile.mvpUrl}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`${profile.name}'s Microsoft MVP profile`}
    >
      {img}
    </a>
  );
}

export function SocialLinks({ profile, className }) {
  return (
    <div className={className}>
      {socialLinks(profile).map((link) => (
        <a key={link.type} href={link.href} target="_blank" rel="noopener noreferrer" aria-label={`${profile.name} on ${link.label}`} title={link.label}>
          {socialIcons[link.type]}
        </a>
      ))}
    </div>
  );
}

function Avatar({ profile }) {
  if (profile.avatar) {
    return <img className={styles.avatar} src={profile.avatar} alt={profile.name} loading="lazy" />;
  }
  return <div className={`${styles.avatar} ${styles.avatarFallback}`}>{profile.initials}</div>;
}

function ContributorCard({ profile }) {
  const authored = profile.testsAuthored.length;
  const contributed = profile.testsContributed.length;
  return (
    <div className={styles.card}>
      {profile.mvp && (
        <MvpBadge profile={profile} className={styles.mvpBadge} />
      )}
      <Link className={styles.cardHeader} to={`/contributors/${profile.id.toLowerCase()}`}>
        <Avatar profile={profile} />
        <div className={styles.cardIdentity}>
          <span className={styles.cardName}>{profile.name}</span>
          {profile.title && <span className={styles.cardTitle} title={profile.title}>{profile.title}</span>}
          {!profile.title && profile.github && <span className={styles.cardTitle}>@{profile.github}</span>}
          {(profile.company || profile.location) && (
            <span className={styles.cardPlace}>
              {profile.company && <span>🏢 {profile.company}</span>}
              {profile.location && <span>{profile.locationFlag || "📍"} {profile.location}</span>}
            </span>
          )}
        </div>
      </Link>
      <div className={styles.cardStats}>
        {authored > 0 && (
          <Link
            className={`${styles.statChip} ${styles.statChipAuthor}`}
            to={`/contributors/${profile.id.toLowerCase()}`}
            title={`View the tests ${profile.name} authored`}
          >
            ✍️ {authored} {authored === 1 ? "test" : "tests"}
          </Link>
        )}
        {profile.github ? (
          <a
            className={styles.statChip}
            href={`https://github.com/maester365/maester/commits?author=${profile.github}`}
            target="_blank"
            rel="noopener noreferrer"
            title={`View ${profile.name}'s commits on GitHub`}
          >
            🤝 {contributed > 0 ? `${contributed} ` : ""}
            {contributed === 1 ? "improvement" : "improvements"}
          </a>
        ) : (
          contributed > 0 && (
            <span className={styles.statChip}>
              🤝 {contributed} {contributed === 1 ? "improvement" : "improvements"}
            </span>
          )
        )}
      </div>
      <SocialLinks profile={profile} className={styles.cardSocials} />
    </div>
  );
}

function formatMonth(isoDate) {
  if (!isoDate) return "";
  return new Date(isoDate).toLocaleDateString("en-US", { month: "short", year: "numeric" });
}

function PaneList({ title, subtitle, profiles, trailing }) {
  if (profiles.length === 0) return null;
  return (
    <section className={styles.paneSection}>
      <h2>{title}</h2>
      <p className={styles.paneSub}>{subtitle}</p>
      <ul>
        {profiles.map((profile) => (
          <li key={profile.id}>
            <Link to={`/contributors/${profile.id.toLowerCase()}`}>
              {profile.avatar ? (
                <img src={profile.avatar} alt={profile.name} loading="lazy" />
              ) : (
                <span className={styles.paneInitials}>{profile.initials}</span>
              )}
              <span className={styles.paneName}>{profile.name}</span>
              <span className={styles.paneTrailing}>{trailing(profile)}</span>
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}

export default function Contributors() {
  const profiles = contributorData.profiles;
  const testCount = Object.keys(contributorData.attributions).length;
  const improvementCount = profiles.reduce((sum, profile) => sum + profile.testsContributed.length, 0);
  const newest = profiles
    .filter((profile) => profile.firstContribution && !profile.pinLast)
    .toSorted((a, b) => b.firstContribution.localeCompare(a.firstContribution))
    .slice(0, 8);
  const mostActive = profiles
    .filter((profile) => profile.recentCommits > 0 && !profile.pinLast)
    .toSorted((a, b) => b.recentCommits - a.recentCommits)
    .slice(0, 8);

  return (
    <Layout title="Contributors" description="Meet the security experts from the Maester community who research, write, and maintain every Maester test.">
      <main className={styles.page}>
        <header className={styles.hero}>
          <h1>Built by the community</h1>
          <p>
            Every Maester test is researched, written, and kept up to date by security experts from around the
            world. This page celebrates the people behind the tests.
          </p>
          <div className={styles.heroStats}>
            <div className={styles.heroStat}>
              <strong>{profiles.length}</strong>
              <span>contributors</span>
            </div>
            <div className={styles.heroStat}>
              <strong>{testCount}</strong>
              <span>tests</span>
            </div>
            <div className={styles.heroStat}>
              <strong>{improvementCount}</strong>
              <span>improvements</span>
            </div>
          </div>
        </header>

        <div className={styles.body}>
          <section className={styles.grid}>
            {profiles.map((profile) => (
              <ContributorCard key={profile.id} profile={profile} />
            ))}
          </section>
          <aside className={styles.sidePane}>
            <PaneList
              title="🌱 New contributors"
              subtitle="The latest security experts to join the project"
              profiles={newest}
              trailing={(profile) => formatMonth(profile.firstContribution)}
            />
            <PaneList
              title="🔥 Most active"
              subtitle="Commits in the last 3 months"
              profiles={mostActive}
              trailing={(profile) => `${profile.recentCommits} ${profile.recentCommits === 1 ? "commit" : "commits"}`}
            />
          </aside>
        </div>

        <section className={styles.cta}>
          <h2>Join them 🔥</h2>
          <p>
            Write a new test, improve an existing one, or polish the docs — every contribution is credited here
            automatically.{" "}
            <Link to="/docs/contributing">Get started with contributing</Link> or{" "}
            <a href="https://github.com/maester365/maester/blob/main/website/contributors/contributors.yml" target="_blank" rel="noopener noreferrer">
              enrich your contributor profile
            </a>
            .
          </p>
        </section>
      </main>
    </Layout>
  );
}
