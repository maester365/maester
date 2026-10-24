import React from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";
import sponsorData from "@site/src/data/sponsors.json";
import styles from "./sponsor.module.css";

// Written weekly by website/scripts/sponsors.mjs: only contributors with a GitHub Sponsors listing.
const { maintainers, testAuthors, contributors, backers = [] } = sponsorData;
const maintainerName = (login) => maintainers.find((m) => m.github === login)?.name.split(" ")[0] ?? login;

const heart = (
  <svg viewBox="0 0 16 16" aria-hidden="true">
    <path d="m8 14.25.345.666a.75.75 0 0 1-.69 0l-.008-.004-.018-.01a7.152 7.152 0 0 1-.31-.17 22.055 22.055 0 0 1-3.434-2.414C2.045 10.731 0 8.35 0 5.5 0 2.836 2.086 1 4.25 1 5.797 1 7.153 1.802 8 3.02 8.847 1.802 10.203 1 11.75 1 13.914 1 16 2.836 16 5.5c0 2.85-2.045 5.231-3.885 6.818a22.066 22.066 0 0 1-3.744 2.584l-.018.01-.006.003h-.002Z" />
  </svg>
);

function SponsorButton({ person, size }) {
  return (
    <a
      className={`${styles.sponsorButton} ${size === "small" ? styles.sponsorButtonSmall : ""}`}
      href={person.sponsorUrl}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`Sponsor ${person.name} on GitHub`}
    >
      {heart}
      <span>Sponsor</span>
    </a>
  );
}

function Identity({ person, className, children }) {
  const content = (
    <>
      <img className={styles.avatar} src={person.avatar} alt="" loading="lazy" />
      <span className={styles.name}>{person.name}</span>
      {children}
    </>
  );
  if (person.contributorPage) {
    return (
      <Link className={className} to={person.contributorPage}>
        {content}
      </Link>
    );
  }
  return (
    <a className={className} href={`https://github.com/${person.github}`} target="_blank" rel="noopener noreferrer">
      {content}
    </a>
  );
}

function MaintainerCard({ person }) {
  return (
    <div className={`${styles.card} ${styles.maintainer}`}>
      <Identity person={person} className={styles.identity}>
        {person.title && <span className={styles.title}>{person.title}</span>}
        <span className={styles.handle}>@{person.github}</span>
      </Identity>
      <SponsorButton person={person} />
    </div>
  );
}

function AuthorCard({ person }) {
  return (
    <div className={`${styles.card} ${styles.author}`}>
      <Identity person={person} className={styles.identity}>
        <span className={styles.chip}>
          ✍️ {person.tests} {person.tests === 1 ? "test" : "tests"}
        </span>
      </Identity>
      <SponsorButton person={person} />
    </div>
  );
}

function ContributorCard({ person }) {
  return (
    <div className={`${styles.card} ${styles.contributor}`}>
      <Identity person={person} className={styles.identity} />
      <SponsorButton person={person} size="small" />
    </div>
  );
}

function listNames(names) {
  if (names.length <= 1) return names.join("");
  return `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
}

function Backers() {
  if (backers.length === 0) return null;
  return (
    <aside id="thank-you" className={styles.thanks}>
      <h2>Thank you to our sponsors {heart}</h2>
      <p className={styles.thanksSub}>
        These people and organisations sponsor, or have sponsored, Maester's maintainers. Their support made Maester
        possible.
      </p>
      <ul className={styles.backers}>
        {backers.map((backer) => (
          <li key={backer.github}>
            <a
              href={`https://github.com/${backer.github}`}
              target="_blank"
              rel="noopener noreferrer"
              title={`${backer.name} sponsors ${listNames(backer.sponsors.map(maintainerName))}`}
            >
              <img
                className={`${styles.backerAvatar} ${backer.organization ? styles.backerOrg : ""}`}
                src={backer.avatar}
                alt=""
                loading="lazy"
              />
              <span className={styles.backerName}>{backer.name}</span>
            </a>
          </li>
        ))}
      </ul>
    </aside>
  );
}

function Section({ id, title, subtitle, people, gridClass, Card }) {
  if (people.length === 0) return null;
  return (
    <section id={id} className={styles.section}>
      <h2>{title}</h2>
      <p className={styles.sectionSub}>{subtitle}</p>
      <div className={`${styles.grid} ${gridClass}`}>
        {people.map((person) => (
          <Card key={person.github} person={person} />
        ))}
      </div>
    </section>
  );
}

export default function Sponsor() {
  const total = maintainers.length + testAuthors.length + contributors.length;
  return (
    <Layout
      title="Sponsor"
      description="Maester is free and open source, and it runs on sponsorships. Sponsor the maintainers and contributors who build it."
    >
      <main className={styles.page}>
        <header className={styles.hero}>
          <div className={styles.heroHeart}>{heart}</div>
          <h1>Maester runs on sponsorships</h1>
          <p>
            Maester is free and open source. Every test, fix and feature is built by people in the community, most of
            them in their own time. Sponsoring them is how you keep Maester going: it pays for the hours that go into
            new tests, keeping up with Microsoft's changes, and answering issues.
          </p>
          <p className={styles.heroNote}>
            Everyone below has GitHub Sponsors turned on. Pick the people whose work you rely on and sponsor them
            directly on GitHub.
          </p>
        </header>

        <div className={`${styles.body} ${backers.length > 0 ? styles.withThanks : ""}`}>
          <div className={styles.main}>
            <Section
              id="maintainers"
              title="Core maintainers"
              subtitle="The people who look after Maester day to day: reviews, releases, the engine and the roadmap."
              people={maintainers}
              gridClass={styles.gridMaintainers}
              Card={MaintainerCard}
            />
            <Section
              id="test-authors"
              title="Test authors"
              subtitle="The security experts who researched and wrote Maester's tests."
              people={testAuthors}
              gridClass={styles.gridAuthors}
              Card={AuthorCard}
            />
            <Section
              id="contributors"
              title="Contributors"
              subtitle="The people who improved the engine, the reports, the docs and everything else."
              people={contributors}
              gridClass={styles.gridContributors}
              Card={ContributorCard}
            />
          </div>
          <Backers />
        </div>

        {total === 0 && <p className={styles.empty}>The list of sponsors is refreshed every week. Check back soon.</p>}

        <section className={styles.cta}>
          <h2>Contributed and not listed?</h2>
          <p>
            Turn on{" "}
            <a href="https://github.com/sponsors" target="_blank" rel="noopener noreferrer">
              GitHub Sponsors
            </a>{" "}
            for your account and you'll show up here after the next weekly refresh. Want to be on this page?{" "}
            <Link to="/docs/contributing">Start contributing</Link>, or meet everyone who has on the{" "}
            <Link to="/contributors">contributors page</Link>.
          </p>
        </section>
      </main>
    </Layout>
  );
}
