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
} from "./generate";
import { Badge, Button, Checkbox, Combobox, Input, RadioCards, Select, Tabs, TabsContent, Textarea } from "./ui";
import styles from "./styles.module.css";

const REPO = "https://github.com/maester365/maester/blob/main/";
const tacticName = Object.fromEntries(data.attack.tactics.map((t) => [t.id, t.name]));
const techniqueById = Object.fromEntries(data.attack.techniques.map((t) => [t.id, t]));
const PREFIX_KEY = "maester.testBuilder.customPrefix";
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
                  IDs match <code>{suite.idPattern}</code>. Files go in <code>{suite.folder}</code>.
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
                  Set your prefix in the field above. The prefixes {data.reservedPrefixes.map((p) => <code key={p}>{p} </code>)} belong to the tests shipped with Maester.
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
            label="Framework controls"
            hint={P.Control.description + " One per line."}
            rubric={R.Control}
            problems={problems}
            notInList={
              <p>
                A built-in test is mapped to a benchmark in files, not in the attribute. Add the test to the requirement in <code>tests/&lt;suite&gt;/frameworks/&lt;framework&gt;.json</code>, and declare a new framework in the suite's <code>suite.json</code>.
              </p>
            }
          >
            <Textarea id="input-control" rows={2} value={state.control} placeholder="nist-800-53-r5:IA-2(1)" onChange={(e) => set({ control: e.target.value })} />
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
            hint={P.License.description + " One element per line. The test is skipped, not failed, in a tenant without the licence."}
            problems={problems}
            notInList={
              <p>
                Known tokens are in <RepoFile path="powershell/assets/MaesterLicenseTable.psd1" />, which also covers government and education variants. A token that is not listed still works: it is matched literally against the tenant's service plan names. Add it to the table when variants need to count as the same licence.
              </p>
            }
          >
            <Textarea id="input-license" rows={2} value={state.license} placeholder="AAD_PREMIUM" onChange={(e) => set({ license: e.target.value })} />
            <div className={styles.tokens}>
              {data.licenses.map((l) => (
                <Button key={l} size="xs" className={styles.token} onClick={() => set({ license: (state.license.trim() ? state.license.trim() + "\n" : "") + l })}>
                  {l}
                </Button>
              ))}
            </div>
          </Field>
          <Field id="permission" name="Permission" label="Permissions" hint={P.Permission.description + " One per line, for example Policy.Read.All."} problems={problems}>
            <Textarea id="input-permission" rows={2} value={state.permission} placeholder="Policy.Read.All" onChange={(e) => set({ permission: e.target.value })} />
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
              Save as <code>{folder + "/Test." + id + ".md"}</code>. The report shows this text, and reviewers read it to check your ratings.
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
