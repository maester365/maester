import React, { useEffect, useMemo, useState } from "react";
import Link from "@docusaurus/Link";
import data from "@site/src/data/test-builder.json";
import Markdown, { firstTable } from "./Markdown";
import {
  NEW,
  emptyState,
  exampleState,
  functionNameFor,
  validate,
  buildPs1,
  buildMd,
  buildCommand,
  folderFor,
  addByHand,
  registryChanges,
  withPrefix,
  parsePermission,
} from "./generate";
import { Badge, Button, Checkbox, Combobox, Input, RadioCards, Select, Tabs, TabsContent } from "./ui";
import LicenseExplorer, { indexCatalog, planLabel } from "./LicenseExplorer";
import styles from "./styles.module.css";

const REPO = "https://github.com/maester365/maester/blob/main/";
const tacticName = Object.fromEntries(data.attack.tactics.map((t) => [t.id, t.name]));
const techniqueById = Object.fromEntries(data.attack.techniques.map((t) => [t.id, t]));
const PREFIX_KEY = "maester.testBuilder.customPrefix";
// Requirements of the frameworks in the repository, and the controls they relate to.
const requirementItems = data.frameworks.flatMap((f) =>
  f.requirements.map((r) => {
    const detail = [f.name, r.level, r.criticality, r.tests.length ? "implemented by " + r.tests.join(", ") : "no test yet"].filter(Boolean).join(" · ");
    return { value: f.key + ":" + r.id, label: f.key + ":" + r.id, hint: detail, search: (f.key + ":" + r.id + " " + detail).toLowerCase() };
  })
);
const relatedItems = [...new Set(data.frameworks.flatMap((f) => f.requirements.flatMap((r) => r.related || [])))].sort().map((c) => ({ value: c, label: c, hint: "Related to requirements in the repository" }));
const nistItems = data.nist.controls.map((c) => ({ value: data.nist.key + ":" + c.id, label: data.nist.key + ":" + c.id, hint: c.title, search: (data.nist.key + ":" + c.id + " " + c.title).toLowerCase() }));
const nistValues = new Set(nistItems.map((i) => i.value));
const controlItems = requirementItems.concat(nistItems, relatedItems.filter((i) => !nistValues.has(i.value)));
const knownLicenses = new Set(data.licenses);

const attackUrl = (id) => "https://attack.mitre.org/techniques/" + id.replace(".", "/") + "/";

function RepoFile({ path }) {
  return (
    <a href={REPO + path} target="_blank" rel="noreferrer">
      <code>{path}</code>
    </a>
  );
}

function Field({ id, name, label, required, hint, rubric, rubricTitle, notInList, problems, children }) {
  const mine = problems.filter((p) => p.field === id);
  return (
    <div className={styles.field} id={"field-" + id}>
      <div className={styles.fieldHead}>
        <label className={styles.label} htmlFor={"input-" + id}>
          {label}
        </label>
        {name && <Badge variant="outline">{name}</Badge>}
        <Badge variant={required ? "primary" : "secondary"} className={styles.need}>
          {required ? "Required" : "Optional"}
        </Badge>
      </div>
      {hint && <p className={styles.hint}>{hint}</p>}
      {children}
      {mine.map((p, i) => (
        <p key={i} className={p.level === "error" ? styles.error : styles.warn} role={p.level === "error" ? "alert" : undefined}>
          {p.text}
        </p>
      ))}
      {rubric && (
        <details className={styles.more}>
          <summary>{rubricTitle || "How to choose: the rubric"}</summary>
          <div className={styles.rubric}>
            <Markdown text={rubric} />
          </div>
        </details>
      )}
      {notInList && (
        <details className={styles.more}>
          <summary>Not in the list?</summary>
          <div className={styles.rubric}>{notInList}</div>
        </details>
      )}
    </div>
  );
}

function Checks({ id, values, options, onChange, describe }) {
  const toggle = (v) => onChange(values.includes(v) ? values.filter((x) => x !== v) : [...values, v]);
  return (
    <div className={styles.checks} id={"input-" + id}>
      {options.map((o) => (
        <Checkbox key={o} checked={values.includes(o)} onCheckedChange={() => toggle(o)}>
          {describe ? describe(o) : o}
        </Checkbox>
      ))}
    </div>
  );
}

const techniqueItems = data.attack.techniques.map((t) => ({ value: t.id, label: t.id + "  " + t.name, hint: t.tactics.map((x) => tacticName[x]).join(", ") }));

function MitrePicker({ selected, none, onChange, onNone }) {
  return (
    <div className={styles.stack}>
      <Checkbox checked={none} onCheckedChange={onNone}>
        None: no attacker behaviour is behind this test (an inventory count, replication health)
      </Checkbox>
      {!none && (
        <>
          <Combobox
            id="input-mitre"
            value=""
            items={techniqueItems}
            placeholder="Look up a technique"
            searchPlaceholder="Search by ID, name or tactic: T1110, phishing, credential access"
            empty={"Nothing in ATT&CK " + data.attack.version + " matches. A retired technique is not listed."}
            keepOpen
            disabledValues={selected}
            onSelect={(id) => !selected.includes(id) && onChange([...selected, id])}
          />
          {selected.length > 0 && (
            <ul className={styles.picked}>
              {selected.map((id) => {
                const t = techniqueById[id];
                return (
                  <li key={id}>
                    <span>
                      <a href={attackUrl(id)} target="_blank" rel="noreferrer">
                        <code>{id}</code>
                      </a>{" "}
                      {t ? t.name : "Unknown"}
                      {t && <span className={styles.tactics}> · {t.tactics.map((x) => tacticName[x]).join(", ")}</span>}
                    </span>
                    <Button variant="ghost" size="xs" aria-label={"Remove " + id} onClick={() => onChange(selected.filter((x) => x !== id))}>
                      Remove
                    </Button>
                  </li>
                );
              })}
            </ul>
          )}
        </>
      )}
    </div>
  );
}

const productSummary = (products) => {
  const names = products.slice(0, 3).map((p) => p.name);
  return "In " + names.join(", ") + (products.length > 3 ? " and " + (products.length - 3) + " more" : "");
};

// Permission: each box is one thing the test needs (all of them); the permissions inside a box are alternatives
// (any one of them), least privileged first.
function PermissionBuilder({ groups, services, onChange }) {
  const registry = services.length ? data.services.filter((s) => services.includes(s.name)) : data.services;
  const [draft, setDraft] = useState({});
  const shown = groups.length ? groups : [[]];
  const update = (index, values) => onChange(shown.map((g, i) => (i === index ? values : g)));
  const filled = shown.filter((g) => g.length);
  const draftFor = (index) => {
    const d = draft[index] || {};
    const service = registry.find((s) => s.name === d.service) || registry[0];
    const kind = (service && service.permissionKinds.find((k) => k.kind === d.kind)) || (service && service.permissionKinds[0]);
    return { service, kind, name: d.name || "" };
  };
  const setDraftFor = (index, patch) => setDraft((all) => ({ ...all, [index]: { ...(all[index] || {}), ...patch } }));
  const describe = (text) => {
    const p = parsePermission(text);
    if (!p) return text;
    const service = data.services.find((s) => s.name === p.service);
    const kind = service && service.permissionKinds.find((k) => k.kind === p.kind);
    return kind ? kind.description : null;
  };

  return (
    <div className={styles.stack}>
      <div className={styles.explain}>
        <p>
          Each box is one thing the test needs, and the test needs <strong>all</strong> of them. Permissions inside one box are <strong>alternatives</strong>: any one of them is enough. Put the least privileged one first.
        </p>
        <p>
          A permission is written <code>&lt;Service&gt;:&lt;Kind&gt;:&lt;Name&gt;</code> and <code>|</code> joins alternatives, so “User.Read.All, and Policy.Read.All or Directory.Read.All” is{" "}
          <code>Permission = ('Graph:Scope:User.Read.All', 'Graph:Scope:Policy.Read.All | Graph:Scope:Directory.Read.All')</code>.
        </p>
      </div>
      {shown.map((group, index) => {
        const d = draftFor(index);
        const value = d.service && d.kind && d.name.trim() ? d.service.name + ":" + d.kind.kind + ":" + d.name.trim() : "";
        const valid = value && parsePermission(value) && !group.includes(value);
        const add = () => {
          if (!valid) return;
          update(index, [...group, value]);
          setDraftFor(index, { name: "" });
        };
        return (
          <React.Fragment key={index}>
            {index > 0 && <div className={styles.or}>and</div>}
            <div className={styles.group}>
              {group.length > 0 && (
                <ul className={styles.picked}>
                  {group.map((text, n) => (
                    <li key={text}>
                      <span>
                        {n > 0 && <span className={styles.and}>or </span>}
                        <code>{text}</code>
                        {describe(text) && <span className={styles.tactics}> · {describe(text)}</span>}
                      </span>
                      <Button variant="ghost" size="xs" aria-label={"Remove " + text} onClick={() => update(index, group.filter((x) => x !== text))}>
                        Remove
                      </Button>
                    </li>
                  ))}
                </ul>
              )}
              {d.service && (
                <div className={styles.groupRow}>
                  <Select id={index === 0 ? "input-permission-service" : undefined} value={d.service.name} onValueChange={(v) => setDraftFor(index, { service: v, kind: undefined })} placeholder="Service" options={registry.map((s) => ({ value: s.name, label: s.name }))} />
                  <Select value={d.kind.kind} onValueChange={(v) => setDraftFor(index, { kind: v })} placeholder="Kind" options={d.service.permissionKinds.map((k) => ({ value: k.kind, label: k.kind, hint: k.description }))} />
                  <Input
                    id={index === 0 ? "input-permission" : undefined}
                    aria-label="Permission name"
                    value={d.name}
                    placeholder={d.kind.example}
                    onChange={(e) => setDraftFor(index, { name: e.target.value })}
                    onKeyDown={(e) => e.key === "Enter" && (e.preventDefault(), add())}
                  />
                  <Button onClick={add} disabled={!valid}>
                    {group.length ? "Add an alternative (or)" : "Add"}
                  </Button>
                  {shown.length > 1 && (
                    <Button variant="ghost" onClick={() => onChange(shown.filter((_, i) => i !== index))}>
                      Remove requirement
                    </Button>
                  )}
                </div>
              )}
            </div>
          </React.Fragment>
        );
      })}
      <div>
        <Button onClick={() => onChange([...shown, []])} disabled={shown[shown.length - 1].length === 0}>
          Add another requirement (and)
        </Button>
      </div>
      {filled.length > 0 && (
        <p className={styles.note}>
          The identity Maester signs in with needs {filled.map((g, i) => (
            <span key={i}>
              {i > 0 && <strong> and </strong>}
              {filled.length > 1 && g.length > 1 && "("}
              {g.map((text) => (parsePermission(text) || { name: text }).name).join(" or ")}
              {filled.length > 1 && g.length > 1 && ")"}
            </span>
          ))}
          . Maester records this on the result; it does not skip the test on it yet.
        </p>
      )}
    </div>
  );
}

function LicenseBuilder({ groups, onChange }) {
  const [catalog, setCatalog] = useState(null);
  const [exploring, setExploring] = useState(null);
  useEffect(() => {
    let live = true;
    import("@site/src/data/license-service-plans.json").then((m) => live && setCatalog(indexCatalog(m.default || m)));
    return () => {
      live = false;
    };
  }, []);
  const items = useMemo(() => {
    if (!catalog) return [];
    return catalog.plans.map((plan) => ({
      value: plan.name,
      label: planLabel(plan),
      plan,
      hint: productSummary(plan.products),
      primary: plan.search,
      weight: plan.products.length,
      search: plan.search + " " + plan.products.map((p) => p.search).join(" "),
    }));
  }, [catalog]);
  // When the search text matched a product, not the plan itself, name that product first.
  const hintFor = (item, q) => {
    if (!q || item.primary.includes(q)) return item.hint;
    const product = item.plan.products.find((p) => p.search.includes(q));
    return product ? "In " + product.name + " (" + product.stringId + ")" + (item.plan.products.length > 1 ? " and " + (item.plan.products.length - 1) + " more" : "") : item.hint;
  };
  const shown = groups.length ? groups : [[]];
  const update = (index, plans) => onChange(shown.map((g, i) => (i === index ? plans : g)));
  const known = (name) => catalog && catalog.planByName[name];
  const label = (name) => (known(name) ? planLabel(known(name)) : name);
  const filled = shown.filter((g) => g.length);

  return (
    <div className={styles.stack}>
      <div className={styles.explain}>
        <p>
          A test requires <strong>service plans</strong>, the building blocks inside a product such as Microsoft 365 E5. Plans inside one box are joined with <strong>and</strong>: the tenant needs all of them. Boxes are joined with <strong>or</strong>: any one box is enough.
        </p>
        <p>
          In the attribute each box is one element and <code>&amp;</code> joins the plans in it, so “Entra ID P1 and Intune, or Entra ID P2” is <code>License = ('AAD_PREMIUM&amp;INTUNE_A', 'AAD_PREMIUM_P2')</code>.
        </p>
      </div>
      {shown.map((group, index) => (
        <React.Fragment key={index}>
          {index > 0 && <div className={styles.or}>or</div>}
          <div className={styles.group}>
            {group.length > 0 && (
              <ul className={styles.picked}>
                {group.map((name, n) => (
                  <li key={name}>
                    <span>
                      {n > 0 && <span className={styles.and}>and </span>}
                      {label(name)}
                      {catalog && !known(name) && <span className={styles.tactics}> · not on Microsoft's list; matched as written</span>}
                      {known(name) && <span className={styles.tactics}> · {productSummary(known(name).products)}</span>}
                      {knownLicenses.has(name) && <span className={styles.tactics}> · Maester also counts its government and education variants</span>}
                    </span>
                    <Button variant="ghost" size="xs" aria-label={"Remove " + name} onClick={() => update(index, group.filter((x) => x !== name))}>
                      Remove
                    </Button>
                  </li>
                ))}
              </ul>
            )}
            <div className={styles.groupRow}>
              <Combobox
                id={index === 0 ? "input-license" : undefined}
                value=""
                items={items}
                hintFor={hintFor}
                placeholder={!catalog ? "Loading the licence list" : group.length ? "And also require" : "Look up a service plan"}
                searchPlaceholder="Search: Entra ID P1, Intune, Microsoft 365 E5, SPE_E5 or a GUID"
                empty="No service plan matches. Type the plan name to use it as written."
                creatable
                createPattern={/^[A-Za-z0-9_-]+$/}
                keepOpen
                disabledValues={group}
                onSelect={(v) => !group.includes(v) && update(index, [...group, v])}
              />
              <Button onClick={() => setExploring(index)} disabled={!catalog}>
                Licence explorer
              </Button>
              {shown.length > 1 && (
                <Button variant="ghost" onClick={() => onChange(shown.filter((_, i) => i !== index))}>
                  Remove alternative
                </Button>
              )}
            </div>
          </div>
        </React.Fragment>
      ))}
      <div>
        <Button onClick={() => onChange([...shown, []])} disabled={shown[shown.length - 1].length === 0}>
          Add an alternative (or)
        </Button>
      </div>
      {filled.length > 0 && (
        <p className={styles.note}>
          The test runs when the tenant has {filled.map((g, i) => (
            <span key={i}>
              {i > 0 && <strong> or </strong>}
              {filled.length > 1 && g.length > 1 && "("}
              {g.map((name) => (known(name) && known(name).friendly) || name).join(" and ")}
              {filled.length > 1 && g.length > 1 && ")"}
            </span>
          ))}
          . Otherwise it is skipped.
        </p>
      )}
      {catalog && exploring !== null && shown[exploring] && (
        <LicenseExplorer
          open
          onOpenChange={(open) => !open && setExploring(null)}
          index={catalog}
          selected={shown[exploring]}
          onAdd={(name) => update(exploring, [...shown[exploring], name])}
          onRemove={(name) => update(exploring, shown[exploring].filter((x) => x !== name))}
        />
      )}
    </div>
  );
}

function CopyBlock({ text, language }) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    const done = () => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, () => {});
  };
  return (
    <div className={styles.codeWrap}>
      <Button size="xs" className={styles.copy} onClick={copy}>
        {copied ? "Copied" : "Copy"}
      </Button>
      <pre className={styles.code} data-language={language}>
        <code>{text}</code>
      </pre>
    </div>
  );
}

export default function TestBuilder() {
  const [state, setState] = useState(exampleState);
  const [tab, setTab] = useState("ps1");
  const set = (patch) => setState((s) => ({ ...s, ...patch }));
  const builtin = state.mode === "builtin";
  const P = data.properties;
  const R = data.rubric;

  const problems = useMemo(() => validate(state, data), [state]);
  const errors = problems.filter((p) => p.level === "error");
  const product = data.products.find((p) => p.key === state.product);
  const features = product ? product.features : [];
  const suite = data.suites.find((s) => s.id === state.suite);
  const area = data.areas.find((a) => a.key === state.area);
  const resourceType = data.resourceTypes.find((r) => r.key === state.resourceType);
  const id = state.id.trim() || (builtin ? "MT.1234" : "CT.1001");
  const folder = folderFor(state, data);
  const changes = registryChanges(state, data);
  const byHand = addByHand(state);
  const firstFramework = state.controls.find((c) => data.frameworks.some((f) => c.startsWith(f.key + ":") && f.requirements.some((r) => f.key + ":" + r.id === c)));

  const need = (name) => builtin && P[name].required !== "No";

  // The prefix of custom tests is remembered in this browser.
  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(PREFIX_KEY);
      if (saved && /^[A-Za-z][A-Za-z0-9]*$/.test(saved)) setState((s) => ({ ...s, customPrefix: saved, id: s.mode === "custom" ? withPrefix(s.id, saved) : s.id }));
    } catch (e) {
      // Storage is not available: the default prefix is used.
    }
  }, []);
  const setPrefix = (value) => {
    const prefix = value.trim();
    const valid = /^[A-Za-z][A-Za-z0-9]*$/.test(prefix);
    setState((s) => ({ ...s, customPrefix: value, id: valid ? withPrefix(s.id, prefix) : s.id }));
    if (valid) {
      try {
        window.localStorage.setItem(PREFIX_KEY, prefix);
      } catch (e) {
        // Not saved; the prefix still applies to this visit.
      }
    }
  };
  const customId = (current) => withPrefix(current, /^[A-Za-z][A-Za-z0-9]*$/.test(state.customPrefix.trim()) ? state.customPrefix.trim() : "CT");
  const setMode = (mode) => set(mode === "custom" ? { mode, id: customId(state.id) } : { mode, tags: "", id: withPrefix(state.id, "MT") });
  const reset = (base) => setState({ ...base, mode: state.mode, customPrefix: state.customPrefix, id: builtin ? base.id : base.id ? customId(base.id) : "" });
  const setProduct = (value) => {
    const next = data.products.find((p) => p.key === value);
    const keepFeature = state.feature === NEW || (next && next.features.some((f) => f.key === state.feature)) || !builtin;
    set({ product: value, feature: keepFeature ? state.feature : "", relatedProducts: state.relatedProducts.filter((r) => r !== value) });
  };

  const registrySelect = (field, options, placeholder) => {
    const change = (value) => (field === "product" ? setProduct(value) : set({ [field]: value }));
    const items = options.map((o) => ({ value: o.key, label: o.name ? o.name : o.key, hint: o.name ? o.key : undefined }));
    return builtin ? (
      <Select id={"input-" + field} value={state[field]} onValueChange={change} placeholder={placeholder} options={items} footer={{ value: NEW, label: "Not in the list: propose a new one" }} />
    ) : (
      <Combobox id={"input-" + field} value={state[field] === NEW ? "" : state[field]} onSelect={change} items={items} placeholder={placeholder + " or type your own"} searchPlaceholder="Search, or type your own value" creatable />
    );
  };

  const newEntry = (field, keys) =>
    state[field] === NEW && (
      <div className={styles.newEntry}>
        {keys.map(([key, placeholder]) => {
          const slot = "new" + field[0].toUpperCase() + field.slice(1);
          return <Input key={key} aria-label={placeholder} placeholder={placeholder} value={state[slot][key]} onChange={(e) => set({ [slot]: { ...state[slot], [key]: e.target.value } })} />;
        })}
        <p className={styles.hint}>A new value is added to the registry in the same pull request. The files to change are listed with the code.</p>
      </div>
    );

  const taxonomyHelp = (what, extra) => (
    <>
      <p>
        Search the list first. {what} is a deliberate addition, because every key becomes a filter in the report. If nothing fits, choose <em>Not in the list</em> above, and add the entry to <RepoFile path="powershell/assets/MaesterTaxonomy.psd1" /> in the same pull request as the first test that needs it.
      </p>
      {extra}
    </>
  );

  const tabs = [
    ["ps1", "Test." + id + ".ps1"],
    ["md", "Test." + id + ".md"],
    ["cmd", "New-MtTest"],
  ];

  return (
    <div className={styles.builder}>
      <div className={styles.form}>
        <section className={styles.section}>
          <h2>Who is the test for?</h2>
          <RadioCards
            label="Who is the test for?"
            columns
            value={state.mode}
            onValueChange={setMode}
            options={[
              { value: "builtin", label: "A test for Maester", text: "You will open a pull request. Values come from Maester's registries and every rubric attribute is required." },
              { value: "custom", label: "My own custom test", text: "It lives in your custom folder. Only the ID and title are required, and you may use your own values." },
            ]}
          />
          <div className={styles.actions}>
            <Button onClick={() => reset(exampleState)}>Load the example</Button>
            <Button onClick={() => reset(emptyState)}>Start empty</Button>
          </div>
        </section>

        <section className={styles.section}>
          <h2>Name it</h2>
          {builtin && (
            <Field id="suite" label="Suite" required hint="The suite decides the ID prefix and the folder. New checks written by the community go in Maester." problems={problems}>
              <Select id="input-suite" value={state.suite} onValueChange={(v) => set({ suite: v })} placeholder="Choose a suite" options={data.suites.map((s) => ({ value: s.id, label: s.name }))} />
              {suite && (
                <p className={styles.hint}>
                  IDs start with {suite.idPrefixes.map((p, i) => (
                    <span key={p}>
                      {i > 0 && " or "}
                      <code>{p}</code>
                    </span>
                  ))}
                  . Files go in <code>{suite.folder}</code>.
                </p>
              )}
            </Field>
          )}
          {!builtin && (
            <Field id="prefix" label="Prefix" required hint="The first part of your test IDs, so they never collide with Maester's own. CT is the default. Change it once, for example to your organization's name, and this browser remembers it." problems={problems}>
              <Input id="input-prefix" value={state.customPrefix} placeholder="CT" onChange={(e) => setPrefix(e.target.value)} />
            </Field>
          )}
          <Field
            id="id"
            name="Id"
            label="ID"
            required
            hint={P.Id.description + " An ID never changes once the test has shipped, because results, configuration and history refer to it."}
            problems={problems}
            notInList={
              builtin ? (
                <p>
                  A new Maester check takes the next free <code>MT.</code> number. Reserve it on <a href="https://github.com/maester365/maester/issues/697" target="_blank" rel="noreferrer">issue 697</a> before you open the pull request, so two contributors do not pick the same one.
                </p>
              ) : (
                <p>
                  Set your prefix in the field above. The prefixes {data.reservedPrefixes.map((p) => <code key={p}>{p} </code>)} are reserved for the tests shipped with Maester and for Maester Packs.
                </p>
              )
            }
          >
            <Input id="input-id" value={state.id} placeholder={builtin ? "MT.1234" : "CT.1001"} onChange={(e) => set({ id: e.target.value })} />
          </Field>
          <Field id="title" name="Title" label="Title" required hint="One line, shown in the report. Say what should be true, so a passing result reads as a fact: “Guest invitations are restricted to administrators.”" problems={problems}>
            <Input id="input-title" value={state.title} onChange={(e) => set({ title: e.target.value.replace(/[\r\n]/g, " ") })} />
          </Field>
          <Field id="functionName" label="Function name" hint={"The file holds one function. Leave empty to use " + functionNameFor(state.id) + "."} problems={problems}>
            <Input id="input-functionName" value={state.functionName} placeholder={functionNameFor(state.id)} onChange={(e) => set({ functionName: e.target.value })} />
          </Field>
        </section>

        <section className={styles.section}>
          <h2>What is it about?</h2>
          <details className={styles.more}>
            <summary>Rate the test, not your tenant</summary>
            <div className={styles.rubric}>
              <Markdown text={R["Rate the test, not your tenant"]} />
            </div>
          </details>
          <Field
            id="product"
            name="Product"
            label="Product"
            required={need("Product")}
            hint={P.Product.description}
            rubric={R.Product}
            problems={problems}
            notInList={taxonomyHelp(
              "A product",
              <p>
                A product entry has a <code>Key</code>, a <code>Name</code>, <code>Aliases</code> and its <code>Features</code>. If the test also needs a connection Maester does not have yet, that is a larger change to <RepoFile path="powershell/assets/MaesterServiceRegistry.psd1" />: open an issue first.
              </p>
            )}
          >
            {registrySelect("product", data.products, "Choose a product")}
            {newEntry("product", [
              ["key", "Key, for example power-platform"],
              ["name", "Display name, for example Power Platform"],
            ])}
          </Field>
          <Field id="feature" name="Feature" label="Feature" required={need("Feature")} hint={P.Feature.description} rubric={R.Feature} problems={problems} notInList={taxonomyHelp("A feature", <p>Add one line to the product's <code>Features</code> list. A feature that would hold one test only is usually too narrow, so prefer an existing one.</p>)}>
            {builtin && !state.product ? <p className={styles.hint}>Choose a product first. A feature belongs to one product.</p> : registrySelect("feature", state.product === NEW ? [] : features, "Choose a feature")}
            {newEntry("feature", [
              ["key", "Key, for example access-reviews"],
              ["name", "Display name, for example Access reviews"],
            ])}
          </Field>
          <Field
            id="relatedProducts"
            name="RelatedProduct"
            label="Related products"
            hint={P.RelatedProduct.description}
            rubric={R.RelatedProduct}
            problems={problems}
          >
            <Checks id="relatedProducts" values={state.relatedProducts} options={data.products.filter((p) => p.key !== state.product).map((p) => p.key)} describe={(k) => data.products.find((p) => p.key === k).name} onChange={(v) => set({ relatedProducts: v })} />
          </Field>
          <Field id="area" name="Area" label="Area" required={need("Area")} hint={P.Area.description} rubric={R.Area} problems={problems} notInList={taxonomyHelp("An area", <p>The thirteen areas are meant to cover every product. When none fits, choose the closest and say so in the pull request, or propose a new one with its description and a row in the rubric's Area table.</p>)}>
            {registrySelect("area", data.areas, "Choose an area")}
            {area && <p className={styles.picked1}>{area.description}</p>}
            {newEntry("area", [
              ["key", "Key, for example physical-security"],
              ["name", "Display name"],
              ["description", "What the area is used for"],
            ])}
          </Field>
          <Field id="resourceType" name="ResourceType" label="Resource type" required={need("ResourceType")} hint={P.ResourceType.description} rubric={R.ResourceType} problems={problems} notInList={taxonomyHelp("A resource type", <p>Add one line to <code>ResourceTypes</code> with a one-line description. For a one-off inventory with no matching type, the rubric says to use <code>Tenant</code>.</p>)}>
            {registrySelect("resourceType", data.resourceTypes, "Choose a resource type")}
            {resourceType && <p className={styles.picked1}>{resourceType.description}</p>}
            {newEntry("resourceType", [
              ["key", "Key in Pascal case, for example AccessPackage"],
              ["description", "One-line description"],
            ])}
          </Field>
        </section>

        <section className={styles.section}>
          <h2>What should be fixed first?</h2>
          <Field id="severity" name="Severity" label="Severity" required={need("Severity")} hint="The risk to the organization while the test fails. Not the effort to fix it and not the disruption of fixing it." rubric={R.Severity} problems={problems} notInList={<p>The five values are fixed. The report, the scores and the <code>-Severity</code> selector depend on them.</p>}>
            <RadioCards label="severity" value={state.severity} options={firstTable(R.Severity)} onValueChange={(v) => set({ severity: v })} />
          </Field>
          {state.severity === "Info" ? (
            <p className={styles.note}>An Info test makes no risk judgement, so it has no user impact or implementation cost and is left out of scores.</p>
          ) : (
            <>
              <Field id="userImpact" name="UserImpact" label="User impact" required={need("UserImpact")} hint={P.UserImpact.description} rubric={R.UserImpact} problems={problems}>
                <RadioCards label="userImpact" value={state.userImpact} options={firstTable(R.UserImpact)} onValueChange={(v) => set({ userImpact: v })} />
              </Field>
              <Field id="implementationCost" name="ImplementationCost" label="Implementation cost" required={need("ImplementationCost")} hint={P.ImplementationCost.description} rubric={R.ImplementationCost} problems={problems}>
                <RadioCards label="implementationCost" value={state.implementationCost} options={firstTable(R.ImplementationCost)} onValueChange={(v) => set({ implementationCost: v })} />
              </Field>
            </>
          )}
        </section>

        <section className={styles.section}>
          <h2>What does it map to?</h2>
          <Field
            id="mitre"
            name="Mitre"
            label="MITRE ATT&CK techniques"
            required={need("Mitre")}
            hint={"The attack techniques the checked control prevents or detects. You pick technique IDs; the tactics are looked up from ATT&CK " + data.attack.version + " and shown in the report."}
            rubric={R.Mitre}
            problems={problems}
            notInList={
              <p>
                The list is the ATT&amp;CK release Maester pins, in <RepoFile path="powershell/assets/MaesterAttackTechniques.json" />. A technique that is missing was retired, or is newer than the pinned release. Use its successor, or update the pinned release with <code>./build/attack/Update-MtAttackTechniques.ps1</code> in a pull request of its own.
              </p>
            }
          >
            <MitrePicker selected={state.mitre} none={state.mitreNone} onChange={(v) => set({ mitre: v })} onNone={(v) => set({ mitreNone: v })} />
          </Field>
          <Field
            id="control"
            name="Control"
            label="Framework requirements"
            hint="Requirements of CIS, CISA, ASD Essential Eight, the ISM, NIST SP 800-53 or any other framework that this test implements or supports. Look one up, or type your own as framework-key:requirement-id. This is the only place a test is mapped to a framework."
            rubric={R.Control}
            problems={problems}
            notInList={
              <>
                <p>
                  The lookup lists the frameworks Maester ships a file for: {data.frameworks.map((f, i) => (
                    <span key={f.key}>
                      {i > 0 && ", "}
                      <RepoFile path={f.file} />
                    </span>
                  ))}
                  . For any other framework, type the reference yourself with a lowercase key, for example <code>nist-800-53-r5:IA-2(1)</code> or <code>iso-27001-2022:A.5.17</code>, and use the same key every time.
                </p>
                <p>
                  The framework file is a catalogue. It holds what a <code>key:id</code> reference cannot: each requirement's level, profile or criticality, the controls it relates to, and the full list of requirements, so typos and gaps are found. A new CIS or CISA requirement is added to that file; the mapping itself is always this attribute.
                </p>
              </>
            }
          >
            <ol className={styles.steps}>
              <li>
                <strong>The requirement the test is written for.</strong> A CIS, CISA or ASD test lists its own requirement first, such as <code>cis-m365:5.1.5.1</code> or <code>essential-eight:ISM-1504</code>.
              </li>
              <li>
                <strong>A CIS, CISA or ASD requirement that asks for the same setting.</strong> Search for the setting or a test ID you know.
              </li>
              <li>
                <strong>NIST SP 800-53 controls</strong>, at most three, when a passing result is direct evidence for them. Skip this when you already listed a <code>cisa-scuba</code> requirement: CISA publishes its NIST mapping and the result gets it from there.
              </li>
            </ol>
            {firstFramework && (
              <p className={styles.note}>
                <code>{firstFramework}</code> is the first reference to a framework Maester has a file for, so it becomes the Benchmark of the result.
              </p>
            )}
            <Combobox
              id="input-control"
              value=""
              items={controlItems}
              placeholder="Look up a requirement"
              searchPlaceholder="Search by framework, ID, control name or test ID: MS.AAD.3, 5.1.5, least privilege"
              creatable
              createPattern={/^[a-z0-9][a-z0-9.-]*:[^\s,]+$/}
              keepOpen
              disabledValues={state.controls}
              onSelect={(v) => !state.controls.includes(v) && set({ controls: [...state.controls, v] })}
            />
            {state.controls.length > 0 && (
              <ul className={styles.picked}>
                {state.controls.map((c) => {
                  const item = controlItems.find((i) => i.value === c);
                  return (
                    <li key={c}>
                      <span>
                        <code>{c}</code>
                        {item && item.hint && <span className={styles.tactics}> · {item.hint}</span>}
                      </span>
                      <Button variant="ghost" size="xs" aria-label={"Remove " + c} onClick={() => set({ controls: state.controls.filter((x) => x !== c) })}>
                        Remove
                      </Button>
                    </li>
                  );
                })}
              </ul>
            )}
          </Field>
        </section>

        <section className={styles.section}>
          <h2>What does it need to run?</h2>
          <Field
            id="services"
            name="Service"
            label="Services"
            required={need("Service")}
            hint="The connections the test needs. The engine checks them before it calls your function and skips the test when one is missing, so the function needs no connection check."
            problems={problems}
            notInList={
              <p>
                Services are registered in <RepoFile path="powershell/assets/MaesterServiceRegistry.psd1" />. A new service also needs a connection probe in the module, so open an issue before the pull request.
              </p>
            }
          >
            <Checkbox checked={state.serviceNone} onCheckedChange={(v) => set({ serviceNone: v })}>
              None: the test needs no connection
            </Checkbox>
            {!state.serviceNone && <Checks id="services" values={state.services} options={data.services.map((s) => s.name)} describe={(n) => (data.services.find((s) => s.name === n).optIn ? n + " (opt-in)" : n)} onChange={(v) => set({ services: v })} />}
          </Field>
          <Field
            id="license"
            name="License"
            label="Licences"
            hint="The service plans the tenant must have. In a tenant without them the test is skipped, not failed."
            problems={problems}
            notInList={
              <>
                <p>
                  The list is Microsoft's <a href="https://learn.microsoft.com/entra/identity/users/licensing-service-plan-reference" target="_blank" rel="noreferrer">product names and service plan identifiers</a> page, refreshed every day. You can also type a name that is not listed yet: it is matched as written against the tenant's service plan names.
                </p>
                <p>
                  For the plans in <RepoFile path="powershell/assets/MaesterLicenseTable.psd1" /> Maester also counts government, education and volume variants as the same licence. Add a plan there when its variants should count too.
                </p>
              </>
            }
          >
            <LicenseBuilder groups={state.license} onChange={(v) => set({ license: v })} />
          </Field>
          <Field
            id="permission"
            name="Permission"
            label="Permissions"
            hint="What the identity Maester signs in with must be granted for the test to read its data. Name the least privileged permission the code uses."
            problems={problems}
            notInList={
              <p>
                The kinds of permission each service has are listed in <RepoFile path="powershell/assets/MaesterServiceRegistry.psd1" />. A test shipped with Maester names only the services it lists under Services.
              </p>
            }
          >
            <PermissionBuilder groups={state.permission} services={state.serviceNone ? [] : state.services} onChange={(v) => set({ permission: v })} />
          </Field>
          <Field id="tenantType" name="TenantType" label="Tenant types" hint={P.TenantType.description + " Leave empty for Workforce only."} problems={problems}>
            <Checks id="tenantType" values={state.tenantType} options={P.TenantType.allowedValues} onChange={(v) => set({ tenantType: v })} />
          </Field>
          <Field id="cloud" name="Cloud" label="Clouds" hint={P.Cloud.description} problems={problems}>
            <Checks id="cloud" values={state.cloud} options={P.Cloud.allowedValues} onChange={(v) => set({ cloud: v })} />
          </Field>
          <Field id="platform" name="Platform" label="Platforms" hint={P.Platform.description} problems={problems}>
            <Checks id="platform" values={state.platform} options={P.Platform.allowedValues} onChange={(v) => set({ platform: v })} />
          </Field>
        </section>

        <section className={styles.section}>
          <h2>Lifecycle and credit</h2>
          <Field id="lifecycle" name="Lifecycle" label="Lifecycle" hint={P.Lifecycle.description} rubric={R["Lifecycle and ReplacedBy"]} problems={problems}>
            <RadioCards label="lifecycle" value={state.lifecycle} options={P.Lifecycle.allowedValues.map((v) => ({ value: v }))} onValueChange={(v) => set({ lifecycle: v })} />
          </Field>
          {(state.lifecycle === "Deprecated" || state.replacedBy) && (
            <Field id="replacedBy" name="ReplacedBy" label="Replaced by" hint={P.ReplacedBy.description} problems={problems}>
              <Input id="input-replacedBy" value={state.replacedBy} placeholder="MT.1300" onChange={(e) => set({ replacedBy: e.target.value })} />
            </Field>
          )}
          <Field id="flags" label="Run behaviour" hint="Leave both off unless you know the test needs them." problems={problems}>
            <Checkbox checked={state.longRunning} onCheckedChange={(v) => set({ longRunning: v })}>
              <code>LongRunning</code>: {P.LongRunning.description}
            </Checkbox>
            <Checkbox checked={state.exclusive} onCheckedChange={(v) => set({ exclusive: v })}>
              <code>Exclusive</code>: {P.Exclusive.description}
            </Checkbox>
          </Field>
          <Field id="author" name="Author" label="Author" required={need("Author")} hint={P.Author.description + " Separate several with commas. Authors are credited on the contributors page."} problems={problems}>
            <Input id="input-author" value={state.author} placeholder="your-github-handle" onChange={(e) => set({ author: e.target.value })} />
          </Field>
          <Field id="contributor" name="Contributor" label="Contributors" hint={P.Contributor.description} problems={problems}>
            <Input id="input-contributor" value={state.contributor} onChange={(e) => set({ contributor: e.target.value })} />
          </Field>
          {!builtin && (
            <Field id="tags" name="Tag" label="Tags" hint={P.Tag.description + " Separate with commas."} rubric={R.Tag} problems={problems}>
              <Input id="input-tags" value={state.tags} placeholder="quarterly-review" onChange={(e) => set({ tags: e.target.value })} />
            </Field>
          )}
          {builtin && (
            <details className={styles.more}>
              <summary>Why is there no Tag field?</summary>
              <div className={styles.rubric}>
                <Markdown text={R.Tag} />
              </div>
            </details>
          )}
        </section>
      </div>

      <aside className={styles.output} aria-label="Generated test">
        <div className={errors.length ? styles.statusBad : styles.statusGood} role="status">
          {errors.length === 0 ? (
            <strong>Meets the rules that can be checked here.</strong>
          ) : (
            <>
              <strong>
                {errors.length} {errors.length === 1 ? "thing" : "things"} to fix
              </strong>
              <ul>
                {errors.slice(0, 6).map((p, i) => (
                  <li key={i}>
                    <a href={"#field-" + p.field}>{p.text}</a>
                  </li>
                ))}
                {errors.length > 6 && <li>and {errors.length - 6} more</li>}
              </ul>
            </>
          )}
        </div>

        <Tabs value={tab} onValueChange={setTab} tabs={tabs}>
          <TabsContent value="ps1">
            <p className={styles.where}>
              Save as <code>{folder + "/Test." + id + ".ps1"}</code>
            </p>
            <CopyBlock text={buildPs1(state)} language="powershell" />
          </TabsContent>
          <TabsContent value="md">
            <p className={styles.where}>
              Save as <code>{folder + "/Test." + id + ".md"}</code>. The report shows this text, and reviewers read it to check your ratings. Replace every placeholder: say what is checked and why it matters, give numbered steps with a direct link to the admin portal page, and link the Microsoft Learn article.
            </p>
            <CopyBlock text={buildMd()} language="markdown" />
          </TabsContent>
          <TabsContent value="cmd">
            <p className={styles.where}>This command writes both files for you.</p>
            <CopyBlock text={buildCommand(state, data)} language="powershell" />
            {byHand.length > 0 && (
              <p className={styles.where}>
                <code>New-MtTest</code> does not write{" "}
                {byHand.map((n, i) => (
                  <span key={n}>
                    {i > 0 && ", "}
                    <code>{n}</code>
                  </span>
                ))}
                . Copy those lines from the <code>.ps1</code> tab.
              </p>
            )}
          </TabsContent>
        </Tabs>

        {changes.length > 0 && (
          <div className={styles.changes}>
            <h3>Also change in your pull request</h3>
            {changes.map((c, i) => (
              <div key={i}>
                <p>
                  <RepoFile path={c.file} /> {c.what}
                </p>
                <CopyBlock text={c.snippet} language="powershell" />
              </div>
            ))}
          </div>
        )}

        <div className={styles.next}>
          <h3>Then</h3>
          <ol>
            <li>
              Check the files without a tenant: <code>Get-MtTest -Path {folder}</code>
            </li>
            {builtin ? (
              <>
                <li>
                  Run the unit tests, which enforce these rules: <code>./powershell/tests/pester.ps1</code>
                </li>
                <li>Open the pull request. A review step reads the test and its Markdown file against the rubric and says which value it expected when one does not fit.</li>
              </>
            ) : (
              <li>
                Run it: <code>Invoke-Maester -TestId {id}</code>
              </li>
            )}
          </ol>
          <p>
            Read more in <Link to="/docs/next/writing-tests">Writing native tests</Link> and the full <Link to="/docs/next/writing-tests/attribute-rubric">attribute rubric</Link>.
          </p>
        </div>
      </aside>
    </div>
  );
}
