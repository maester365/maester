import React from "react";
import styles from "./styles.module.css";

// Every component carries styles.root so the scoped colour tokens apply wherever it sits in the post.
const root = (cls) => `${styles.root} ${cls}`;

export function Hero({ eyebrow, title, lede, facts = [] }) {
  return (
    <div className={root(styles.hero)}>
      <div className={styles.eyebrow}>{eyebrow}</div>
      <div className={styles.heroTitle}>{title}</div>
      <p className={styles.lede}>{lede}</p>
      <div className={styles.facts}>
        {facts.map(([value, label]) => (
          <div className={styles.fact} key={label}>
            <b>{value}</b>
            <span>{label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function Chapter({ n, children }) {
  return (
    <div className={root(`${styles.eyebrow} ${styles.chapter}`)}>
      {children ?? `Part ${n}`}
    </div>
  );
}

export function Say({ label = "In short", children }) {
  return (
    <div className={root(styles.say)}>
      <b>{label}</b>
      {children}
    </div>
  );
}

export function Timeline({ items }) {
  return (
    <div className={root(styles.timeline)}>
      {items.map(({ when, what, primary }) => (
        <div className={`${styles.when} ${primary ? styles.primary : ""}`} key={when}>
          <b>{when}</b>
          <span>{what}</span>
        </div>
      ))}
    </div>
  );
}

export function Split({ children }) {
  return <div className={root(styles.split)}>{children}</div>;
}

export function Panel({ title, variant, children }) {
  const cls = variant === "old" ? styles.panelOld : variant === "now" ? styles.panelNow : "";
  return (
    <div className={`${styles.panel} ${cls}`}>
      <h4>{title}</h4>
      {children}
    </div>
  );
}

export function Pipeline({ steps }) {
  return (
    <ol className={root(styles.pipeline)}>
      {steps.map(({ title, text, cs }) => (
        <li key={title} className={cs ? styles.cs : undefined}>
          <div className={styles.step}>
            <h4>
              {title}
              {cs && <span className={styles.lang}>C#</span>}
            </h4>
            <p>{text}</p>
          </div>
        </li>
      ))}
    </ol>
  );
}

export function Gates({ gates }) {
  return (
    <div className={root(styles.gates)}>
      {gates.map(([name, reason], i) => (
        <React.Fragment key={name}>
          {i > 0 && <span className={styles.arrow}>→</span>}
          <div className={styles.gate}>
            <b>{name}</b>
            <span>{reason}</span>
          </div>
        </React.Fragment>
      ))}
    </div>
  );
}

export function Layers({ layers }) {
  return (
    <div className={root(styles.layers)} aria-label="Config layers, highest priority first">
      {layers.map(({ name, text, rank }) => (
        <div className={styles.layer} key={name}>
          <div>
            <code>{name}</code>
            <br />
            <small>{text}</small>
          </div>
          <small>{rank}</small>
        </div>
      ))}
    </div>
  );
}

const pillTone = {
  Passed: styles.good,
  Failed: styles.bad,
  Error: styles.bad,
  Skipped: styles.warn,
  Investigate: styles.warn,
};

export function Statuses({ items }) {
  return (
    <div className={root(styles.statuses)}>
      {items.map((s) => (
        <span className={`${styles.pill} ${pillTone[s] ?? ""}`} key={s}>
          {s}
        </span>
      ))}
    </div>
  );
}

export function Files({ files }) {
  return (
    <div className={root(styles.files)}>
      {files.map(({ name, tag, text }) => (
        <div className={styles.file} key={name}>
          {tag && <span className={styles.fileTag}>{tag}</span>}
          <h4>{name}</h4>
          <p>{text}</p>
        </div>
      ))}
    </div>
  );
}
