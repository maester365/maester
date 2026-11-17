import React, { useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import Link from "@site/src/react/shims/Link.jsx";
import data from "@site/src/data/test-builder.json";
import Markdown, { firstTable } from "./Markdown";
import { NEW, emptyState, exampleState, functionNameFor, validate, buildPs1, buildMd, buildCommand, buildAiPrompt, folderFor, addByHand, registryChanges, withPrefix, splitList, stateFromTest, parsePermission, PARAMETER_TYPES, emptyParameter, parameterForSetting, resolveParameter, settingOf, buildConfigExample, scaffoldedSettings } from "./generate";
import { AttributeIcon, Badge, Button, Checkbox, Combobox, DeleteIcon, Flag, HelpButton, LevelIcon, OptionIcon, PlusIcon, osGlyph, Input, RadioCards, RadioPills, Select, Sheet, Tabs, TabsContent, Textarea } from "./ui";
import GitHubPeople from "./GitHubPeople";
import { fieldHelp } from "./help";
import LicenseExplorer, { indexCatalog, planLabel } from "./LicenseExplorer";
import styles from "./styles.module.css";
import { productIcon, productInitials, featureIcon } from "../../lib/report-icons.mjs";

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

// Only one help panel is open at a time; this holds the id of the field it belongs to.
const HelpContext = React.createContext({ openId: null, setOpenId: () => {} });

// With the form and the code side by side, the help panel covers the code column and leaves the form in view.
// In one column it slides in at the right edge of the window.
function useDock(open) {
  const [place, setPlace] = useState(undefined);
  useEffect(() => {
    if (!open) return undefined;
    const measure = () => {
      const dock = document.querySelector("[data-help-dock]");
      const form = dock && dock.previousElementSibling;
      if (!dock || !form) return setPlace(undefined);
      const side = dock.getBoundingClientRect().left > form.getBoundingClientRect().right;
      setPlace(side ? { left: Math.max(0, dock.getBoundingClientRect().left - 12), width: "auto" } : undefined);
    };
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, [open]);
  return place;
}

// Links to the guides open in the help panel on this page, so the form stays in view while you read them: the
// sidebar's guides, links in the page and the builder, and links in a field's help. Links to other guides inside
// a guide open there too; anything else opens in a new tab.
const SIDEBAR_LINKS = "#starlight__sidebar ul.top-level a[href]";
const PAGE_LINKS = "main a[href]:not([target]), [data-help-sheet] a[href]:not([target])";
const isGuide = (url) => url.origin === window.location.origin && url.pathname.startsWith("/docs/");
const plainClick = (e) => e.button === 0 && !e.metaKey && !e.ctrlKey && !e.shiftKey && !e.altKey && !e.defaultPrevented;

function useGuides(setOpenId) {
  const [guide, setGuide] = useState(null);
  const latest = useRef(null);
  const openGuide = useCallback(
    (href) => {
      const url = new URL(href, window.location.href);
      latest.current = url.href;
      setGuide((g) => ({ href: url.href, title: g && g.href === url.href ? g.title : "Loading…", html: null, error: false }));
      setOpenId("guide");
      fetch(url.pathname)
        .then((r) => (r.ok ? r.text() : Promise.reject(new Error(r.status))))
        .then((text) => {
          if (latest.current !== url.href) return;
          const page = new DOMParser().parseFromString(text, "text/html");
          const content = page.querySelector(".sl-markdown-content");
          if (!content) throw new Error("No content");
          // The styles and scripts a guide's components bring (code blocks bring their own) load once into this page.
          content.querySelectorAll('link[rel="stylesheet"], script[src]').forEach((el) => {
            const isLink = el.tagName === "LINK";
            const src = new URL(el.getAttribute(isLink ? "href" : "src"), url).pathname;
            if (!document.head.querySelector(isLink ? 'link[href="' + src + '"]' : 'script[src="' + src + '"]')) {
              const copy = document.createElement(isLink ? "link" : "script");
              if (isLink) {
                copy.rel = "stylesheet";
                copy.href = src;
              } else {
                copy.type = "module";
                copy.src = src;
              }
              document.head.appendChild(copy);
            }
            el.remove();
          });
          content.querySelectorAll("a[href], img[src]").forEach((el) => {
            const attr = el.tagName === "A" ? "href" : "src";
            const raw = el.getAttribute(attr);
            if (raw.startsWith("#")) return;
            const target = new URL(raw, url);
            el.setAttribute(attr, target.origin === window.location.origin ? target.pathname + target.search + target.hash : target.href);
            if (attr === "href" && !isGuide(target)) {
              el.setAttribute("target", "_blank");
              el.setAttribute("rel", "noreferrer");
            }
          });
          const h1 = page.querySelector("h1");
          setGuide({ href: url.href, title: h1 ? h1.textContent.trim() : url.pathname, html: content.innerHTML, error: false });
        })
        .catch(() => latest.current === url.href && setGuide((g) => ({ ...g, title: "Could not load the guide", error: true })));
    },
    [setOpenId]
  );

  // Sidebar links only while the sidebar is shown beside the page (Starlight's 50rem breakpoint); below that it is
  // a menu over the page, and a guide opens as a page of its own.
  useEffect(() => {
    const onClick = (e) => {
      if (!plainClick(e) || !e.target.closest) return;
      const a = (window.matchMedia("(min-width: 50rem)").matches && e.target.closest(SIDEBAR_LINKS)) || e.target.closest(PAGE_LINKS);
      if (!a) return;
      const url = new URL(a.href, window.location.href);
      if (!isGuide(url)) return;
      e.preventDefault();
      openGuide(url.href);
    };
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  }, [openGuide]);

  return [guide, openGuide];
}

function GuidePanel({ guide, open, onClose, openGuide }) {
  const place = useDock(open);
  const body = useRef(null);
  useEffect(() => {
    // A new guide starts at the top of the panel.
    if (body.current && body.current.parentElement) body.current.parentElement.scrollTop = 0;
  }, [guide]);
  const onClick = (e) => {
    const a = e.target.closest && e.target.closest("a[href]");
    if (!a || !plainClick(e)) return;
    const raw = a.getAttribute("href");
    if (raw.startsWith("#")) {
      e.preventDefault();
      const target = body.current && body.current.querySelector("#" + CSS.escape(decodeURIComponent(raw.slice(1))));
      if (target) target.scrollIntoView({ behavior: "smooth", block: "start" });
      return;
    }
    const url = new URL(a.href, window.location.href);
    if (isGuide(url) && url.pathname !== window.location.pathname) {
      e.preventDefault();
      openGuide(url.href);
    }
  };
  return (
    <Sheet
      open={open}
      onOpenChange={(o) => !o && onClose()}
      title={guide ? guide.title : ""}
      style={place}
      actions={
        guide && (
          <a className={styles.newTab} href={guide.href} target="_blank" rel="noreferrer" aria-label="Open the guide in a new tab" title="Open in a new tab">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M15 3h6v6M10 14 21 3M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
            </svg>
          </a>
        )
      }
    >
      {guide && guide.error && <p>The guide could not be loaded. Open it in a new tab instead.</p>}
      {guide && !guide.error && !guide.html && <p className={styles.note}>Loading…</p>}
      {guide && guide.html && <div ref={body} className={"sl-markdown-content " + styles.guide} onClick={onClick} dangerouslySetInnerHTML={{ __html: guide.html }} />}
    </Sheet>
  );
}

// A help panel and the button that opens it. The panel is rendered by the field itself, so it follows the form's state.
function Help({ id, title, badge, label, children }) {
  const { openId, setOpenId } = useContext(HelpContext);
  const open = openId === id;
  const place = useDock(open);
  return (
    <>
      <HelpButton open={open} label={title} onClick={() => setOpenId(open ? null : id)}>
        {label}
      </HelpButton>
      <Sheet open={open} onOpenChange={(o) => !o && setOpenId(null)} title={title} badge={badge} style={place}>
        {children}
      </Sheet>
    </>
  );
}

// A form field. The input and any problems are shown inline; what the attribute means, the rubric and how to
// add a missing value open in the help panel, so the form stays short.
function Field({ id, name, label, required, hint, guide, rubric, rubricTitle, notInList, problems, children }) {
  const mine = problems.filter((p) => p.field === id);
  const { builtin } = useContext(HelpContext);
  const extra = fieldHelp(id, builtin);
  const hasHelp = hint || guide || rubric || notInList || extra;
  return (
    <div className={styles.field} id={"field-" + id}>
      <div className={styles.fieldHead}>
        <label className={styles.label} htmlFor={"input-" + id}>
          <AttributeIcon name={FIELD_ICONS[id]} />
          {label}
        </label>
        {!required && <span className={styles.optional}>Optional</span>}
        {hasHelp && (
          <span className={styles.helpSlot}>
            <Help id={id} title={label} badge={name}>
              {hint && <p className={styles.lead}>{hint}</p>}
              {extra && extra.more && <Markdown text={extra.more} />}
              {extra && extra.empty && (
                <>
                  <h3>If you leave it empty</h3>
                  <Markdown text={extra.empty} />
                </>
              )}
              {guide}
              {rubric && (
                <>
                  <h3>{rubricTitle || "How to choose"}</h3>
                  <Markdown text={rubric} />
                </>
              )}
              {notInList && (
                <>
                  <h3>Not in the list?</h3>
                  {notInList}
                </>
              )}
            </Help>
          </span>
        )}
      </div>
      {children}
      {mine.map((p, i) => (
        <p key={i} className={p.level === "error" ? styles.error : styles.warn} role={p.level === "error" ? "alert" : undefined}>
          {p.text}
        </p>
      ))}
    </div>
  );
}

function Checks({ id, values, options, onChange, describe, iconFor }) {
  const toggle = (v) => onChange(values.includes(v) ? values.filter((x) => x !== v) : [...values, v]);
  return (
    <div className={styles.checks} id={"input-" + id}>
      {options.map((o) => (
        <Checkbox key={o} checked={values.includes(o)} onCheckedChange={() => toggle(o)}>
          <span className={styles.withIcon}>
            {iconFor && <OptionIcon {...iconFor(o)} />}
            {describe ? describe(o) : o}
          </span>
        </Checkbox>
      ))}
    </div>
  );
}

const productIconOf = (key) => ({ icon: productIcon(key), initials: productIcon(key) ? undefined : productInitials(key) });

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
                    <Button variant="ghost" size="icon" aria-label={"Remove " + id} title="Remove" onClick={() => onChange(selected.filter((x) => x !== id))}>
                      <DeleteIcon />
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

// Parameters: the values an administrator can change. One card per parameter. A parameter bound to a registered
// setting takes its type, default and allowed values from the registry, so only its name and description are typed.
function ParameterBuilder({ parameters, builtin, onChange }) {
  const update = (index, patch) => onChange(parameters.map((p, i) => (i === index ? { ...p, ...patch } : p)));
  const remove = (index) => onChange(parameters.filter((_, i) => i !== index));
  const bindable = data.settings.filter((s) => !s.connection && s.type !== "object");
  const unused = bindable.filter((s) => !parameters.some((p) => settingOf(p, data) === s));
  return (
    <div className={styles.stack}>
      <datalist id="parameter-names">
        {data.parameterNames.map((n) => (
          <option key={n.name} value={n.name}>
            {n.type}
          </option>
        ))}
      </datalist>
      {parameters.map((raw, index) => {
        const p = resolveParameter(raw, data);
        const setting = settingOf(raw, data);
        const used = data.parameterNames.find((n) => n.name.toLowerCase() === p.name.trim().toLowerCase());
        return (
          <div className={styles.group} key={index}>
            <div className={styles.paramGrid}>
              <label className={styles.miniField}>
                <span>Name</span>
                <Input
                  id={index === 0 ? "input-parameters" : undefined}
                  list="parameter-names"
                  placeholder="MaximumInactiveDays"
                  value={raw.name}
                  onChange={(e) => update(index, { name: e.target.value.replace(/\s/g, "") })}
                />
              </label>
              <div className={styles.miniField}>
                <span>Type</span>
                {setting ? (
                  <div>
                    <Badge>{setting.type}</Badge>
                  </div>
                ) : (
                  <Select value={raw.type} onValueChange={(v) => update(index, { type: v })} placeholder="Type" options={PARAMETER_TYPES.map((t) => ({ value: t, label: t }))} />
                )}
              </div>
            </div>
            <label className={styles.miniField}>
              <span>Description</span>
              <Input placeholder="One line: what the value changes" value={raw.description} onChange={(e) => update(index, { description: e.target.value.replace(/[\r\n]/g, " ") })} />
            </label>
            {setting ? (
              <p className={styles.hint}>
                Bound to the setting <code>{setting.name}</code>, which an administrator sets once in <code>GlobalSettings</code>. The settings registry gives it its type
                {p.default ? ", its default (" + p.default + ")" : ""}
                {p.allowedValues.length ? " and its allowed values (" + p.allowedValues.join(", ") + ")" : ""}.
              </p>
            ) : (
              <>
                {raw.type === "switch" ? (
                  <p className={styles.hint}>A switch is off by default. Name it after what turning it on does.</p>
                ) : (
                  <div className={styles.paramGrid}>
                    <label className={styles.miniField}>
                      <span>Default</span>
                      <Input
                        placeholder={raw.type === "int" ? "90" : raw.type === "bool" ? "true or false" : raw.type === "string[]" ? "Comma-separated; empty for none" : "Empty for none"}
                        value={raw.default}
                        onChange={(e) => update(index, { default: e.target.value })}
                      />
                    </label>
                    {raw.type === "int" && (
                      <>
                        <label className={styles.miniField}>
                          <span>Lowest allowed</span>
                          <Input placeholder="1" value={raw.min} onChange={(e) => update(index, { min: e.target.value })} />
                        </label>
                        <label className={styles.miniField}>
                          <span>Highest allowed</span>
                          <Input placeholder="365" value={raw.max} onChange={(e) => update(index, { max: e.target.value })} />
                        </label>
                      </>
                    )}
                    {(raw.type === "string" || raw.type === "string[]") && (
                      <>
                        <label className={styles.miniField}>
                          <span>Allowed values</span>
                          <Input placeholder="Comma-separated; empty for any" value={raw.allowed} onChange={(e) => update(index, { allowed: e.target.value })} />
                        </label>
                        <div className={styles.miniField}>
                          <span>Holds</span>
                          <Select
                            value={raw.kind || "none"}
                            onValueChange={(v) => update(index, { kind: v === "none" ? "" : v })}
                            placeholder="Holds"
                            options={[{ value: "none", label: "Plain text" }].concat(data.parameterKinds.map((k) => ({ value: k, label: k })))}
                          />
                        </div>
                      </>
                    )}
                  </div>
                )}
                {!builtin && (
                  <label className={styles.miniField}>
                    <span>Shared setting of your own (optional)</span>
                    <Input placeholder="Contoso.Regions" value={raw.setting} onChange={(e) => update(index, { setting: e.target.value.trim() })} />
                  </label>
                )}
              </>
            )}
            {used && !setting && used.type === p.type && (
              <p className={styles.hint}>
                {used.tests} built-in {used.tests === 1 ? "test uses" : "tests use"} <code>{used.name}</code>. Reuse the name only if it means the same thing here.
              </p>
            )}
            <div>
              <Button variant="ghost" onClick={() => remove(index)}>
                <DeleteIcon />
                Remove {raw.name.trim() || "parameter"}
              </Button>
            </div>
          </div>
        );
      })}
      <div className={styles.groupRow}>
        <Select
          value=""
          onValueChange={(v) => onChange([...parameters, parameterForSetting(data.settings.find((s) => s.name === v))])}
          placeholder="Add a shared setting"
          options={unused.map((s) => ({ value: s.name, label: s.name, hint: s.description }))}
        />
        <Button onClick={() => onChange([...parameters, { ...emptyParameter }])}>
          <PlusIcon />
          Add a parameter
        </Button>
      </div>
    </div>
  );
}

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
                      <Button variant="ghost" size="icon" aria-label={"Remove " + text} title="Remove" onClick={() => update(index, group.filter((x) => x !== text))}>
                        <DeleteIcon />
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
                    <PlusIcon />
                    {group.length ? "Add an alternative (or)" : "Add"}
                  </Button>
                  {shown.length > 1 && (
                    <Button variant="ghost" onClick={() => onChange(shown.filter((_, i) => i !== index))}>
                      <DeleteIcon />
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
          <PlusIcon />
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
                    <Button variant="ghost" size="icon" aria-label={"Remove " + name} title="Remove" onClick={() => update(index, group.filter((x) => x !== name))}>
                      <DeleteIcon />
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
                <AttributeIcon name="explore" />
                Licence explorer
              </Button>
              {shown.length > 1 && (
                <Button variant="ghost" onClick={() => onChange(shown.filter((_, i) => i !== index))}>
                  <DeleteIcon />
                  Remove alternative
                </Button>
              )}
            </div>
          </div>
        </React.Fragment>
      ))}
      <div>
        <Button onClick={() => onChange([...shown, []])} disabled={shown[shown.length - 1].length === 0}>
          <PlusIcon />
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

// The icon beside each field's label and each step. An attribute the report shows has the report's icon.
const FIELD_ICONS = {
  suite: "source", prefix: "tag", id: "id", title: "title", functionName: "code",
  product: "product", feature: "feature", relatedProducts: "related", area: "area", resourceType: "resource",
  severity: "severity", userImpact: "impact", implementationCost: "effort",
  mitre: "attack", control: "framework",
  services: "service", license: "licence", permission: "permission",
  tenantType: "tenant", cloud: "cloud", platform: "platform",
  parameters: "params",
  lifecycle: "lifecycle", replacedBy: "related", flags: "duration", author: "person", contributor: "impact", tags: "tag",
};
const STEP_ICONS = { start: "person", name: "id", about: "product", priority: "severity", mapping: "framework", services: "service", licences: "licence", permissions: "permission", environment: "cloud", parameters: "params", lifecycle: "lifecycle" };
const LIFECYCLE_ICONS = { Preview: ["preview", "info"], Stable: ["stable", "ok"], Deprecated: ["deprecated", "low"] };

// Services show the icon of the product they connect to. Microsoft Graph has no icon of its own in the set, so it
// shows Microsoft 365's; Dataverse has none either and shows its initials.
const SERVICE_PRODUCT = { ActiveDirectory: "ad", Azure: "azure", AzureDevOps: "azure-devops", ExchangeOnline: "exchange", GitHub: "github", Graph: "microsoft-365", SecurityCompliance: "purview", SharePointOnline: "sharepoint", Teams: "teams" };
const serviceIconOf = (name) => (SERVICE_PRODUCT[name] && productIcon(SERVICE_PRODUCT[name]) ? { icon: productIcon(SERVICE_PRODUCT[name]) } : { initials: name.slice(0, 2) });

// Tenant types: the value written to the attribute stays Workforce or External; the label says what External
// means. Workforce shows the Entra ID icon the report uses. External shows Microsoft's External ID icon
// (public/img/icons/external-id.svg, from https://az-icons.com/icon/external-id-modified, unchanged).
const TENANT_TYPES = {
  Workforce: { label: "Workforce", icon: productIcon("entra") },
  External: { label: "External (Consumer)", icon: "/img/icons/external-id.svg" },
};

// Clouds: the country whose cloud it is, shown as a flag. Commercial is the worldwide cloud and shows a globe.
const CLOUDS = {
  Commercial: { label: "Worldwide" },
  GCC: { country: "us", label: "United States" },
  GCCHigh: { country: "us", label: "United States" },
  DoD: { country: "us", label: "United States" },
  China: { country: "cn", label: "China" },
  Bleu: { country: "fr", label: "France" },
  Delos: { country: "de", label: "Germany" },
  GovSG: { country: "sg", label: "Singapore" },
};

// The rating fields show a level icon on each choice, so the scale reads at a glance.
const SEVERITY_LEVEL = { Critical: 4, High: 3, Medium: 2, Low: 1, Info: 0 };
const SCALE_LEVEL = { Low: 1, Medium: 2, High: 3 };
const SCALE_TONE = { Low: "low", Medium: "medium", High: "high" };
const severityOptions = (options) => options.map((o) => ({ ...o, icon: <LevelIcon level={SEVERITY_LEVEL[o.value]} of={4} tone={o.value.toLowerCase()} /> }));
const scaleOptions = (options) => options.map((o) => ({ ...o, icon: <LevelIcon level={SCALE_LEVEL[o.value]} of={3} tone={SCALE_TONE[o.value]} /> }));

// The form is shown one step at a time. Each step lists the fields whose problems count against it.
const STEPS = [
  { key: "start", label: "Who it is for", fields: [] },
  { key: "name", label: "Name", fields: ["suite", "prefix", "id", "title", "functionName"] },
  { key: "about", label: "Subject", fields: ["product", "feature", "relatedProducts", "area", "resourceType"] },
  { key: "priority", label: "Priority", fields: ["severity", "userImpact", "implementationCost"] },
  { key: "mapping", label: "Mapping", fields: ["mitre", "control"] },
  { key: "services", label: "Service connections", fields: ["services"] },
  { key: "licences", label: "Licences", fields: ["license"] },
  { key: "permissions", label: "Permissions", fields: ["permission"] },
  { key: "environment", label: "Where it applies", fields: ["tenantType", "cloud", "platform"] },
  { key: "parameters", label: "Parameters", fields: ["parameters"] },
  { key: "lifecycle", label: "Lifecycle and credit", fields: ["lifecycle", "replacedBy", "flags", "author", "contributor", "tags"] },
];
const stepOfField = (field) => (STEPS.find((s) => s.fields.includes(field)) || STEPS[0]).key;
const stepOfHash = (hash) => {
  const value = (hash || "").replace(/^#/, "");
  if (value.startsWith("field-")) return stepOfField(value.slice(6));
  return value === "ai" || STEPS.some((s) => s.key === value) ? value : null;
};

// The list of steps: in the site's sidebar on a wide screen, a row above the form on a narrow one. A step shows
// a tick once it has been opened and has nothing to fix, or the number of things to fix.
function StepList({ steps, step, onStep, className }) {
  return (
    <ol className={className} aria-label="Steps">
      {/* Not a step: the prompt uses whatever the steps hold so far, so it sits apart, after them. */}
      {steps.map((s, index) => (
        <li key={s.key}>
          <button type="button" className={styles.step} data-state={s.errors ? "bad" : s.done ? "done" : "todo"} title={s.label + (s.errors ? ": " + s.errors + " to fix" : "")} aria-current={s.key === step ? "step" : undefined} onClick={() => onStep(s.key)}>
            <span className={styles.stepMark} data-state={s.errors ? "bad" : s.done ? "done" : "todo"} aria-hidden="true">
              {s.errors ? s.errors : s.done ? "✓" : index + 1}
            </span>
            <AttributeIcon name={STEP_ICONS[s.key]} className={styles.stepIcon} />
            <span className={styles.stepLabel}>{s.label}</span>
            {s.optional && <span className={styles.stepNote}>Optional</span>}
            {s.errors > 0 && (
              <span className={styles.srOnly}>
                , {s.errors} to fix
              </span>
            )}
          </button>
        </li>
      ))}
      <li className={styles.stepApart}>
        <button type="button" className={styles.step} title="Write the test with AI" aria-current={step === "ai" ? "step" : undefined} onClick={() => onStep("ai")}>
          <span className={styles.stepMark} data-state="ai" aria-hidden="true">
            <AttributeIcon name="spark" />
          </span>
          <AttributeIcon name="spark" className={styles.stepIcon} />
          <span className={styles.stepLabel}>Write it with AI</span>
        </button>
      </li>
    </ol>
  );
}

// Start from a test that ships with Maester: type its ID or part of its title. The list is fetched the first
// time the picker is used, so the page does not carry all the tests.
function ExistingTestPicker({ onLoad }) {
  const [tests, setTests] = useState(null);
  const [failed, setFailed] = useState(false);
  const load = useCallback(() => {
    if (tests || failed) return;
    fetch("/data/builder-tests.json")
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(String(response.status)))))
      .then(setTests, () => setFailed(true));
  }, [tests, failed]);
  const items = useMemo(() => (tests || []).map((t) => ({ value: t.Id, label: t.Id + "  " + t.Title, hint: t.Suite, ...productIconOf(t.Product) })), [tests]);
  return (
    <div className={styles.existing} onPointerDown={load} onFocus={load}>
      <Combobox
        id="input-existing"
        value=""
        items={items}
        placeholder="Start from an existing test: type an ID or a title"
        searchPlaceholder="MT.1001, CIS.M365.2.1.9, device code, DKIM"
        empty={failed ? "The list of tests could not be loaded." : tests ? "No test matches." : "Loading the tests…"}
        onSelect={(id) => {
          const test = (tests || []).find((t) => t.Id === id);
          if (test) onLoad(test);
        }}
      />
    </div>
  );
}

export default function TestBuilder() {
  const [state, setState] = useState(exampleState);
  const [tab, setTab] = useState("ps1");
  const [loaded, setLoaded] = useState(null);
  const [goal, setGoal] = useState("");
  const [step, setStepState] = useState("start");
  const [seen, setSeen] = useState(["start"]);
  const [railHost, setRailHost] = useState(null);
  const formRef = useRef(null);
  const jump = useRef(null);
  const [jumps, setJumps] = useState(0);
  const [helpId, setHelpId] = useState(null);
  const helpContext = useMemo(() => ({ openId: helpId, setOpenId: setHelpId, builtin: state.mode === "builtin" }), [helpId, state.mode]);
  const [guide, openGuide] = useGuides(setHelpId);
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

  // Steps. The address keeps the step, so a link or a reload opens it; a link to a field opens the field's step.
  const setStep = useCallback((key, field) => {
    setStepState(key);
    setSeen((list) => (list.includes(key) ? list : [...list, key]));
    setHelpId(null);
    try {
      window.history.replaceState(null, "", "#" + key);
    } catch (e) {
      // The address is not updated; the step still opens.
    }
    jump.current = { field };
    setJumps((n) => n + 1);
  }, []);
  const goField = (field) => setStep(stepOfField(field), field);
  // After the step is on the page: bring the field, or the top of the form, into view.
  useEffect(() => {
    if (!jump.current) return;
    const { field } = jump.current;
    jump.current = null;
    const target = field ? document.getElementById("field-" + field) : formRef.current;
    if (!target) return;
    if (field) target.scrollIntoView({ block: "center" });
    else if (target.getBoundingClientRect().top < 0) target.scrollIntoView({ block: "start" });
    const input = field && document.getElementById("input-" + field);
    if (input && input.focus) input.focus({ preventScroll: true });
  }, [jumps]);
  useEffect(() => {
    setRailHost(document.getElementById("mt-builder-steps"));
    const open = () => {
      const hash = window.location.hash;
      const key = stepOfHash(hash);
      if (key) setStep(key, hash.startsWith("#field-") ? hash.slice(7) : undefined);
    };
    open();
    window.addEventListener("hashchange", open);
    return () => window.removeEventListener("hashchange", open);
  }, [setStep]);
  const steps = STEPS.map((s) => {
    const count = errors.filter((p) => s.fields.includes(p.field)).length;
    return { ...s, errors: count, done: seen.includes(s.key) && count === 0 && s.key !== step, optional: !builtin && !["start", "name"].includes(s.key) };
  });
  const stepIndex = STEPS.findIndex((s) => s.key === step);

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

  // Products show the icon the report and the test catalog use; features show theirs when they have one.
  const iconOf = (field, key) =>
    field === "product" ? productIconOf(key) : field === "feature" && state.product ? { icon: featureIcon(state.product, key) } : {};

  const registrySelect = (field, options, placeholder) => {
    const change = (value) => (field === "product" ? setProduct(value) : set({ [field]: value }));
    const items = options.map((o) => ({ value: o.key, label: o.name ? o.name : o.key, hint: o.name ? o.key : undefined, ...iconOf(field, o.key) }));
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

  const configExample = buildConfigExample(state, data);
  const handParameters = (state.parameters || []).filter((p) => p.name.trim()).length - scaffoldedSettings(state, data).length;

  const tabs = [
    ["ps1", "Test." + id + ".ps1"],
    ["md", "Test." + id + ".md"],
    ["cmd", "New-MtTest"],
  ];

  return (
    <HelpContext.Provider value={helpContext}>
    <div className={styles.shell}>
    <div className={styles.builder}>
      <div className={styles.form} ref={formRef}>
        <StepList steps={steps} step={step} onStep={setStep} className={styles.stepStrip} />
        <section className={styles.section} id={"step-" + "start"} hidden={step !== "start"}>
          <h2>Who is the test for?</h2>
          <p className={styles.intro}>
            Every Maester test declares what it is about, how urgent a failure is and what it needs to run, in a <code>[MaesterTest()]</code> attribute. Pick the values step by step and the code updates as you go. The help button beside a field says what it means, what happens when you leave it empty, and the rule reviewers apply.
          </p>
          <RadioCards
            label="Who is the test for?"
            columns
            value={state.mode}
            onValueChange={setMode}
            options={[
              { value: "builtin", icon: <AttributeIcon name="maester" />, label: "A test for Maester", text: "You will open a pull request. Values come from Maester's registries and every rubric attribute is required." },
              { value: "custom", icon: <AttributeIcon name="source" />, label: "My own custom test", text: "It lives in your custom folder. Only the ID and title are required, and you may use your own values." },
            ]}
          />
          <div className={styles.actions}>
            <Button onClick={() => { setLoaded(null); reset(exampleState); }}>Load the example</Button>
            <Button onClick={() => { setLoaded(null); reset(emptyState); }}>Start empty</Button>
          </div>
          <ExistingTestPicker
            onLoad={(test) => {
              setState((s) => ({ ...stateFromTest(test, data), customPrefix: s.customPrefix }));
              setLoaded({ id: test.Id, title: test.Title, instanceSource: false });
            }}
          />
          <p className={styles.note}>
            <AttributeIcon name="spark" /> Want an AI assistant to write the test? Fill in what you know, then open{" "}
            <button type="button" className={styles.linkButton} onClick={() => setStep("ai")}>
              Write it with AI
            </button>
            . <Link to="/docs/writing-tests/with-ai">How it works</Link>.
          </p>
          {loaded && (
            <p className={styles.note}>
              Loaded <a href={"/docs/tests/" + loaded.id}>{loaded.id}</a>: its attributes and parameters are in the form. The code on the right is still the builder's template, not the test's own code, so copy the attribute and the <code>param()</code> block from it, not the body.
            </p>
          )}
        </section>

        <section className={styles.section} id={"step-" + "name"} hidden={step !== "name"}>
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

        <section className={styles.section} id={"step-" + "about"} hidden={step !== "about"}>
          <div className={styles.sectionHead}>
            <h2>What is it about?</h2>
            <Help id="rate-the-test" title="Rate the test, not your tenant" label="Rate the test, not your tenant">
              <Markdown text={R["Rate the test, not your tenant"]} />
            </Help>
          </div>
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
            <Checks id="relatedProducts" values={state.relatedProducts} options={data.products.filter((p) => p.key !== state.product).map((p) => p.key)} describe={(k) => data.products.find((p) => p.key === k).name} iconFor={productIconOf} onChange={(v) => set({ relatedProducts: v })} />
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

        <section className={styles.section} id={"step-" + "priority"} hidden={step !== "priority"}>
          <h2>What should be fixed first?</h2>
          <Field id="severity" name="Severity" label="Severity" required={need("Severity")} hint="The risk to the organization while the test fails. Not the effort to fix it and not the disruption of fixing it." rubric={R.Severity} problems={problems} notInList={<p>The five values are fixed. The report, the scores and the <code>-Severity</code> selector depend on them.</p>}>
            <RadioPills label="severity" value={state.severity} options={severityOptions(firstTable(R.Severity))} onValueChange={(v) => set({ severity: v })} />
          </Field>
          {state.severity === "Info" ? (
            <p className={styles.note}>An Info test makes no risk judgement, so it has no user impact or implementation cost and is left out of scores.</p>
          ) : (
            <>
              <Field id="userImpact" name="UserImpact" label="User impact" required={need("UserImpact")} hint={P.UserImpact.description} rubric={R.UserImpact} problems={problems}>
                <RadioPills label="userImpact" value={state.userImpact} options={scaleOptions(firstTable(R.UserImpact))} onValueChange={(v) => set({ userImpact: v })} />
              </Field>
              <Field id="implementationCost" name="ImplementationCost" label="Implementation cost" required={need("ImplementationCost")} hint={P.ImplementationCost.description} rubric={R.ImplementationCost} problems={problems}>
                <RadioPills label="implementationCost" value={state.implementationCost} options={scaleOptions(firstTable(R.ImplementationCost))} onValueChange={(v) => set({ implementationCost: v })} />
              </Field>
            </>
          )}
        </section>

        <section className={styles.section} id={"step-" + "mapping"} hidden={step !== "mapping"}>
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
            guide={
              <>
                <h3>What to list, in order</h3>
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
              </>
            }
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
                      <Button variant="ghost" size="icon" aria-label={"Remove " + c} title="Remove" onClick={() => set({ controls: state.controls.filter((x) => x !== c) })}>
                        <DeleteIcon />
                      </Button>
                    </li>
                  );
                })}
              </ul>
            )}
          </Field>
        </section>

        <section className={styles.section} id={"step-" + "services"} hidden={step !== "services"}>
          <h2>Which service connections does it need?</h2>
          <Field
            id="services"
            name="Service"
            label="Service connections"
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
            {!state.serviceNone && <Checks id="services" values={state.services} options={data.services.map((s) => s.name)} iconFor={serviceIconOf} onChange={(v) => set({ services: v })} />}
          </Field>
        </section>

        <section className={styles.section} id={"step-" + "licences"} hidden={step !== "licences"}>
          <h2>Which licences does the tenant need?</h2>
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
        </section>

        <section className={styles.section} id={"step-" + "permissions"} hidden={step !== "permissions"}>
          <h2>Which permissions does it need?</h2>
          <Field
            id="permission"
            name="Permission"
            label="Permissions"
            hint="What the identity Maester signs in with must be granted for the test to read its data. Name the least privileged permission the code uses."
            problems={problems}
            notInList={
              <p>
                The kinds of permission each service has are listed in <RepoFile path="powershell/assets/MaesterServiceRegistry.psd1" />. A test shipped with Maester names only the services it lists under Service connections.
              </p>
            }
          >
            <PermissionBuilder groups={state.permission} services={state.serviceNone ? [] : state.services} onChange={(v) => set({ permission: v })} />
          </Field>
        </section>

        <section className={styles.section} id={"step-" + "environment"} hidden={step !== "environment"}>
          <h2>Where does it apply?</h2>
          <p className={styles.intro}>Leave these empty unless the test is only valid in some tenants, clouds or operating systems. Most tests leave them empty.</p>
          <Field id="tenantType" name="TenantType" label="Tenant types" hint={P.TenantType.description + " Workforce is an organization's own tenant; External is a Microsoft Entra External ID tenant for customers. Leave empty for Workforce only."} problems={problems}>
            <Checks id="tenantType" values={state.tenantType} options={P.TenantType.allowedValues} describe={(o) => TENANT_TYPES[o]?.label || o} iconFor={(o) => ({ icon: TENANT_TYPES[o]?.icon })} onChange={(v) => set({ tenantType: v })} />
          </Field>
          <Field id="cloud" name="Cloud" label="Clouds" hint={P.Cloud.description} problems={problems}>
            <Checks id="cloud" values={state.cloud} options={P.Cloud.allowedValues} iconFor={(o) => ({ glyph: <Flag country={CLOUDS[o]?.country} label={CLOUDS[o]?.label} /> })} onChange={(v) => set({ cloud: v })} />
          </Field>
          <Field id="platform" name="Platform" label="Platforms" hint={P.Platform.description} problems={problems}>
            <Checks id="platform" values={state.platform} options={P.Platform.allowedValues} iconFor={(o) => ({ glyph: osGlyph(o) })} onChange={(v) => set({ platform: v })} />
          </Field>
        </section>

        <section className={styles.section} id={"step-" + "parameters"} hidden={step !== "parameters"}>
          <h2>What can an administrator change?</h2>
          <div className={styles.explain}>
            <p>
              A <strong>parameter</strong> is a value of this test that an administrator can change in <code>maester-config.json</code>, such as a threshold or a list of exceptions.
            </p>
            <p>
              A <strong>shared setting</strong> is one value that many tests use: a fact about the tenant, or a choice the organization makes once, such as its emergency access accounts or the domains that never send email. The administrator sets it once under <code>GlobalSettings</code> and every test that binds a parameter to it receives it. The help button explains how to add a new one.
            </p>
          </div>
          <Field
            id="parameters"
            label="Parameters"
            hint="A value an administrator may need to change: a threshold, a list of exceptions, a choice. Leave this empty when the check has nothing to tune. Every parameter has a default, so the test runs with no configuration."
            rubric={R["Parameter names"]}
            rubricTitle="How to name a parameter, and when to bind a setting"
            problems={problems}
            guide={
              <>
                <h3>What a shared setting is</h3>
                <p>
                  Some values mean the same thing to every test that needs them: which accounts are the emergency access accounts, which domains are parked. Asking the administrator to repeat such a value on every test would be tedious and easy to get wrong. A shared setting holds it once, under <code>GlobalSettings</code> in <code>maester-config.json</code>.
                </p>
                <p>
                  A test does not read the setting itself. It declares a parameter bound to it, <code>[MaesterParameter(Setting = 'ParkedDomains')]</code>, and the engine fills the parameter in. The result records the value and that it came from the setting, and a <code>TestSettings</code> row can still override it for one test.
                </p>
                <p>
                  Bind a parameter only when the organization sets the value once and it means the same to every test. A value a benchmark sets, such as a lockout threshold, is never a shared setting: it stays a parameter of that test, with the benchmark's value as the default.
                </p>
                <h3>Use a shared setting that exists</h3>
                <p>
                  Choose it under <em>Add a shared setting</em>. The builder writes the parameter with the setting's type, default and allowed values, which must not be changed.
                </p>
                <h3>Add a new shared setting</h3>
                {builtin ? (
                  <ol className={styles.steps}>
                    <li>
                      <strong>Name it after what it holds</strong>, never after a test or a suite, in PascalCase and plural for a list: <code>ParkedDomains</code>, not <code>Cis218Domains</code>.
                    </li>
                    <li>
                      <strong>Register it</strong> in <RepoFile path="powershell/assets/MaesterSettings.psd1" />, in the same pull request, with its <code>Type</code>, <code>Default</code>, <code>Sensitive</code> and <code>Description</code>. Add <code>AllowedValues</code> for a fixed set of choices, <code>Kind</code> when a string holds something a picker can offer (a domain, a group), and <code>Items</code> for a list of objects.
                      <CopyBlock text={"ExcludedRegions = @{ Type = 'string[]'; Default = @(); Sensitive = $false; Description = 'Regions the organization does not operate in.' }"} language="powershell" />
                    </li>
                    <li>
                      <strong>Bind the parameter</strong> in the test with the same type, default and allowed values. The builder lists a setting only once it is registered, so write this one by hand:
                      <CopyBlock text={"# Regions the organization does not operate in.\n[MaesterParameter(Setting = 'ExcludedRegions')]\n[string[]] $ExcludedRegions = @()"} language="powershell" />
                    </li>
                    <li>
                      <strong>Pass the value on.</strong> Give it to the helper functions that need it as an argument. A helper never reads a setting that tests bind, or it would ignore the value the test was given.
                    </li>
                    <li>
                      <strong>Document it</strong> in the <code>GlobalSettings</code> table of <RepoFile path="website/docs/configuration/run-configuration.md" />.
                    </li>
                    <li>
                      <strong>Regenerate and test.</strong> Run <code>./build/website/Update-MtTestBuilderData.ps1</code>, so this page offers the setting, then <code>./powershell/tests/pester.ps1</code>. The unit tests fail when a parameter's type or default differs from its setting.
                    </li>
                  </ol>
                ) : (
                  <ol className={styles.steps}>
                    <li>
                      <strong>Name it <code>Namespace.Key</code></strong>, with your organization or pack as the namespace: <code>Contoso.Regions</code>. The dot keeps it apart from Maester's own settings, and Maester does not report it as a typo.
                    </li>
                    <li>
                      <strong>Add a parameter</strong> here and type that name under <em>Shared setting of your own</em>. Give it a default, so the test runs before anyone sets the value.
                    </li>
                    <li>
                      <strong>Set the value</strong> once under <code>GlobalSettings</code> in <code>maester-config.json</code>. Every test of yours that binds <code>Contoso.Regions</code> receives it. The example below the form shows the file.
                    </li>
                    <li>
                      <strong>In a Maester Pack</strong>, also declare the setting under <code>Settings</code> in <code>maester-pack.json</code>, with its type. Maester then checks the value in the config before a run.
                    </li>
                  </ol>
                )}
              </>
            }
          >
            <ParameterBuilder parameters={state.parameters || []} builtin={builtin} onChange={(v) => set({ parameters: v })} />
          </Field>
          {configExample && (
            <div className={styles.field}>
              <p className={styles.hint}>
                How an administrator sets {(state.parameters || []).length === 1 ? "it" : "them"} in <code>maester-config.json</code>. A shared setting is set once under <code>GlobalSettings</code>, and the test's row under <code>TestSettings</code> can still override it for this test.
              </p>
              <CopyBlock text={configExample} language="json" />
            </div>
          )}
        </section>

        <section className={styles.section} id={"step-" + "lifecycle"} hidden={step !== "lifecycle"}>
          <h2>Lifecycle and credit</h2>
          <Field id="lifecycle" name="Lifecycle" label="Lifecycle" hint={P.Lifecycle.description} rubric={R["Lifecycle and ReplacedBy"]} problems={problems}>
            <RadioPills label="lifecycle" value={state.lifecycle} options={P.Lifecycle.allowedValues.map((v) => ({ value: v, icon: <AttributeIcon name={LIFECYCLE_ICONS[v][0]} tone={LIFECYCLE_ICONS[v][1]} /> }))} onValueChange={(v) => set({ lifecycle: v })} />
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
          <Field id="author" name="Author" label="Author" required={need("Author")} hint={P.Author.description + " Search GitHub by name or handle; the lookup reads public profiles only. Authors are credited on the contributors page."} problems={problems}>
            <GitHubPeople id="input-author" value={splitList(state.author)} onChange={(v) => set({ author: v.join(", ") })} />
          </Field>
          <Field id="contributor" name="Contributor" label="Contributors" hint={P.Contributor.description} problems={problems}>
            <GitHubPeople id="input-contributor" value={splitList(state.contributor)} onChange={(v) => set({ contributor: v.join(", ") })} />
          </Field>
          {!builtin && (
            <Field id="tags" name="Tag" label="Tags" hint={P.Tag.description + " Separate with commas."} rubric={R.Tag} problems={problems}>
              <Input id="input-tags" value={state.tags} placeholder="quarterly-review" onChange={(e) => set({ tags: e.target.value })} />
            </Field>
          )}
          {builtin && (
            <p className={styles.note}>
              <Help id="no-tags" title="Why is there no Tag field?" badge="Tag" label="Why is there no Tag field?">
                <Markdown text={R.Tag} />
              </Help>
            </p>
          )}
        </section>
        <section className={styles.section} id="step-ai" hidden={step !== "ai"}>
          <h2>Write it with AI</h2>
          <div className={styles.explain}>
            <p>
              An AI coding assistant such as GitHub Copilot or Claude Code can write the test from a prompt. The prompt below carries the values you picked in the steps, points the assistant at Maester's guides and tells it how to check its work. The ID and the title are enough to start; every other value you pick is one less for it to guess.
            </p>
            <p>
              {builtin ? "Run it in a clone of the Maester repository, which has agents and skills for writing a check." : "Run it in the folder that holds your custom tests. The assistant does not need the Maester repository."} <Link to="/docs/writing-tests/with-ai">How this works, and how to check the result</Link>.
            </p>
          </div>
          <div className={styles.field}>
            <label className={styles.miniField}>
              <span>What should the test verify?</span>
              <Textarea value={goal} rows={4} placeholder="Guest users cannot invite other guests. The setting is 'Guest invite restrictions' under External collaboration settings, and it should be 'Only users assigned to specific admin roles'." onChange={(e) => setGoal(e.target.value)} />
            </label>
          </div>
          <div className={styles.field}>
            <p className={styles.hint}>Copy this into your assistant.</p>
            <CopyBlock text={buildAiPrompt(state, data, goal)} language="markdown" />
            <p className={styles.hint}>Read what the assistant writes before you run it: check the endpoint and property names against Microsoft Learn, and run the test on a tenant you know.</p>
          </div>
        </section>
        {stepIndex >= 0 && (
        <div className={styles.stepNav}>
          <Button disabled={stepIndex === 0} onClick={() => setStep(STEPS[stepIndex - 1].key)}>
            Back
          </Button>
          <span className={styles.stepCount}>
            Step {stepIndex + 1} of {STEPS.length}
          </span>
          {stepIndex < STEPS.length - 1 ? (
            <Button variant="primary" onClick={() => setStep(STEPS[stepIndex + 1].key)}>
              Next: {STEPS[stepIndex + 1].label}
            </Button>
          ) : (
            <span className={styles.stepCount}>{errors.length ? "Fix what is listed with the code, then copy it." : "Done. Copy the code."}</span>
          )}
        </div>
        )}
      </div>
      {railHost && createPortal(<StepList steps={steps} step={step} onStep={setStep} className={styles.stepRail} />, railHost)}

      <aside className={styles.output} aria-label="Generated test" data-help-dock>
        {/* Only problems are shown here; a test that meets the rules needs no banner. */}
        <div className={styles.status} role="status" aria-live="polite">
          {errors.length > 0 && (
            <div className={styles.statusBad}>
              <strong>
                {errors.length} {errors.length === 1 ? "thing" : "things"} to fix
              </strong>
              <ul>
                {errors.slice(0, 6).map((p, i) => (
                  <li key={i}>
                    <a
                      href={"#field-" + p.field}
                      onClick={(e) => {
                        e.preventDefault();
                        goField(p.field);
                      }}
                    >
                      {p.text}
                    </a>
                  </li>
                ))}
                {errors.length > 6 && <li>and {errors.length - 6} more</li>}
              </ul>
            </div>
          )}
        </div>

        <Tabs value={tab} onValueChange={setTab} tabs={tabs}>
          <TabsContent value="ps1">
            <p className={styles.where}>
              Save as <code>{folder + "/Test." + id + ".ps1"}</code>
            </p>
            <CopyBlock text={buildPs1(state, data)} language="powershell" />
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
            {handParameters > 0 && (
              <p className={styles.where}>
                <code>New-MtTest -Setting</code> writes the parameters bound to a shared setting. Copy the {handParameters === 1 ? "other parameter" : "other " + handParameters + " parameters"} of the <code>param()</code> block from the <code>.ps1</code> tab.
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
            Read more in <Link to="/docs/writing-tests">Writing native tests</Link> and the full <Link to="/docs/writing-tests/attribute-rubric">attribute rubric</Link>.
          </p>
        </div>
      </aside>
    </div>
    </div>
    <GuidePanel guide={guide} open={helpId === "guide"} onClose={() => setHelpId(null)} openGuide={openGuide} />
    </HelpContext.Provider>
  );
}
