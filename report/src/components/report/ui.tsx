// Small pieces every view uses: product marks, attribute icons, result and severity labels, bars, copyable
// commands and the toast that confirms a copy.

import { useEffect, useRef, useState, type ReactNode } from "react"
import { ICON_BASE, PRODUCT_ICONS, featureIcon } from "@/lib/featureIcons"
import { RESULT_LABEL, RESULTS, type Tally } from "@/lib/model"
// Microsoft's product icons, always shown beside the product's name. When one cannot load (offline), the tile
// with the product's initials takes its place.
const INITIALS: Record<string, string> = { exchange: "Ex", purview: "Pv", "microsoft-365": "365", fabric: "Fb", github: "GH", ad: "AD" }

// Product icons that failed to load in this session, so the next mark shows initials straight away.
const failed = new Set<string>()

export function ProductMark({ product, size = "" }: { product: string | null; size?: "" | "sm" | "lg" }) {
  const [broken, setBroken] = useState(false)
  if (!product) return null
  if (PRODUCT_ICONS[product] && !broken && !failed.has(product)) {
    return <img className={`mt-pm ${size}`} data-product={product} src={`${ICON_BASE}/products/${PRODUCT_ICONS[product]}`} alt="" aria-hidden="true" referrerPolicy="no-referrer" onError={() => { failed.add(product); setBroken(true) }} />
  }
  return <span className={`mt-pm ${size}`} aria-hidden="true">{INITIALS[product] || product.slice(0, 2)}</span>
}

// One stroke icon per attribute, drawn here so the report needs no icon library for them.
const ICON: Record<string, string> = {
  result: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 12l3 3 5-6",
  product: "M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8",
  related: "M8 7h11v11M19 7 5 21",
  feature: "M12 3l9 5-9 5-9-5 9-5zM3 13l9 5 9-5",
  area: "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3z",
  resource: "M12 4a8 8 0 1 0 0 16 8 8 0 0 0 0-16zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z",
  severity: "M12 4l9 16H3L12 4zM12 10v4M12 17h.01",
  impact: "M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM3 20c0-3 3-5 6-5s6 2 6 5M16 5a3 3 0 0 1 0 6M21 20c0-2.5-1.5-4.3-4-4.8",
  effort: "M14.7 6.3a4 4 0 0 0-5.4 5.2L3 17.8V21h3.2l6.3-6.3a4 4 0 0 0 5.2-5.4l-2.6 2.6-2.4-.6-.6-2.4z",
  lifecycle: "M6 3v12M18 9a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM6 21a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM18 9a9 9 0 0 1-9 9",
  service: "M9 2v6M15 2v6M6 8h12v4a6 6 0 0 1-12 0V8zM12 18v4",
  licence: "M4 7h16v10H4zM8 11h5M8 14h3M16 11v3",
  permission: "M6 11h12v10H6zM8 11V7a4 4 0 0 1 8 0v4",
  duration: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2",
  source: "M3 7h6l2 2h10v10H3z",
  pack: "M21 8l-9-5-9 5v8l9 5 9-5V8zM12 13l9-5M12 13 3 8M12 13v8M7.5 5.5l9 5",
  framework: "M9 5h11M9 12h11M9 19h11M4 5l1 1 2-2M4 12l1 1 2-2M4 19l1 1 2-2",
  attack: "M12 3v4M12 17v4M3 12h4M17 12h4M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z",
  tag: "M3 12V3h9l9 9-9 9-9-9zM7.5 7.5h.01",
  history: "M3 12a9 9 0 1 0 3-6.7M3 4v4h4M12 7v5l3 2",
  params: "M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M14 4v4M8 10v4M16 16v4",
  shim: "M8 7h8M8 12h8M8 17h5M4 3h16v18H4z",
  finding: "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM21 21l-5-5",
  fix: "M9 12l2 2 4-4M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3z",
  search: "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM21 21l-4.5-4.5",
  menu: "M4 6h16M4 12h16M4 18h16",
  moon: "M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z",
  sparkle: "M12 3l1.8 4.7 4.7 1.8-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8zM19 15l.8 2.2 2.2.8-2.2.8L19 21l-.8-2.2-2.2-.8 2.2-.8z",
  close: "M6 6l12 12M18 6 6 18",
  report: "M6 3h9l4 4v14H6zM14 3v5h5M9 13h7M9 17h5",
  tenant: "M4 21V6l8-3 8 3v15M9 9h1M14 9h1M9 13h1M14 13h1M10 21v-4h4v4",
  chevron: "M6 9l6 6 6-6",
  prev: "M15 6l-6 6 6 6",
  home: "M3 11l9-7 9 7M5 10v10h14V10M10 20v-5h4v5",
  check: "M5 12l5 5 9-10",
  next: "M9 6l6 6-6 6",
  maximize: "M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5",
  restore: "M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5",
}
export type IconName = keyof typeof ICON

/** A feature's msicons icon (lib/featureIcons.ts), shown only beside the feature's name. */
export function FeatureMark({ product, feature }: { product: string | null; feature: string | null }) {
  const [broken, setBroken] = useState(false)
  const src = featureIcon(product, feature)
  return src && !broken ? <img className="mt-fm" src={src} alt="" width="18" height="18" loading="lazy" referrerPolicy="no-referrer" onError={() => setBroken(true)} /> : null
}

export function Icon({ name, className = "mt-ai" }: { name: IconName; className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={ICON[name]} />
    </svg>
  )
}

export function Flame({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={Math.round(size * 1.2)} viewBox="0 0 24 28" aria-hidden="true">
      <path d="M12 1c1.4 4-1.2 6.4-2.6 8.3C7.6 11.6 6 13.6 6 16.6 6 21 8.7 25 12 25s6-3.1 6-7.4c0-2.3-.9-4-2.1-5.4.2 1.9-.7 3.4-2 3.8.7-4.2-.4-10.3-1.9-15z" fill="var(--mt-ember)" />
    </svg>
  )
}

export const Pill = ({ result }: { result: string }) => <span className={`mt-pill mt-r-${result}`}>{RESULT_LABEL[result] || (result === "none" ? "No test" : result)}</span>
export const Sev = ({ severity }: { severity: string }) => (severity ? <span className={`mt-sev mt-s-${severity}`}>{severity}</span> : null)

export function Bar({ tally, thin }: { tally: Partial<Tally> & { total: number }; thin?: boolean }) {
  const total = tally.total || 1
  const t = tally as Record<string, number>
  return (
    <div className={`mt-bar${thin ? " thin" : ""}`} role="img" aria-label={`${t.Passed || 0} passed, ${t.Failed || 0} failed of ${tally.total}`}>
      {RESULTS.filter((r) => t[r]).map((r) => <i key={r} className={`mt-b-${r}`} style={{ width: `${(t[r] / total) * 100}%` }} />)}
    </div>
  )
}

export function Legend({ tally }: { tally: Tally }) {
  return (
    <div className="mt-legend">
      {RESULTS.filter((r) => tally[r]).map((r) => <span key={r}><i className={`mt-b-${r}`} />{tally[r]} {RESULT_LABEL[r].toLowerCase()}</span>)}
    </div>
  )
}

// Copy text to the clipboard and say so. Falls back to a selected textarea when the clipboard API is refused.
let showToast: ((message: string) => void) | null = null
export function copyText(text: string, message = "Copied") {
  const done = () => showToast?.(message)
  const fallback = () => {
    const area = document.createElement("textarea")
    area.value = text
    document.body.appendChild(area)
    area.select()
    try { document.execCommand("copy"); done() } catch { showToast?.("Select the text and copy it") }
    area.remove()
  }
  try { navigator.clipboard.writeText(text).then(done, fallback) } catch { fallback() }
}

export function Toaster() {
  const [message, setMessage] = useState<string | null>(null)
  useEffect(() => {
    let timer: number | undefined
    showToast = (m) => { setMessage(m); window.clearTimeout(timer); timer = window.setTimeout(() => setMessage(null), 1800) }
    return () => { showToast = null; window.clearTimeout(timer) }
  }, [])
  return message ? <div className="mt-toast" role="status">{message}</div> : null
}

export function Cmd({ command, wrap }: { command: string; wrap?: boolean }) {
  return (
    <span className={`mt-cmd${wrap ? " wrap" : ""}`}>
      <span>{command}</span>
      <button type="button" onClick={() => copyText(command, "Command copied")} aria-label={`Copy ${command}`}>Copy</button>
    </span>
  )
}

/** A menu of options that looks like the rest of the report, in place of the browser's own select. Arrow keys move,
 *  Enter or Space picks, Escape or a click outside closes. */
export function Dropdown({ label, value, options, onChange }: { label: string; value: string; options: { value: string; label: string; icon?: ReactNode }[]; onChange: (value: string) => void }) {
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(0)
  const root = useRef<HTMLDivElement>(null)
  const list = useRef<HTMLUListElement>(null)
  const current = options.find((o) => o.value === value) || options[0]
  useEffect(() => {
    if (!open) return
    setActive(Math.max(0, options.findIndex((o) => o.value === value)))
    list.current?.focus()
    const away = (e: MouseEvent) => { if (!root.current?.contains(e.target as Node)) setOpen(false) }
    document.addEventListener("mousedown", away)
    return () => document.removeEventListener("mousedown", away)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])
  const pick = (i: number) => { onChange(options[i].value); setOpen(false); (root.current?.querySelector("button") as HTMLElement | null)?.focus() }
  return (
    <div className="mt-dd" ref={root}>
      <button type="button" className="mt-btn mt-dd-btn" aria-haspopup="listbox" aria-expanded={open} onClick={() => setOpen((o) => !o)}
        onKeyDown={(e) => { if (e.key === "ArrowDown" || e.key === "ArrowUp") { e.preventDefault(); setOpen(true) } }}>
        <span className="mt-muted">{label}</span>{current?.icon}<b>{current?.label}</b><Icon name="chevron" />
      </button>
      {open && (
        <ul ref={list} className="mt-dd-list" role="listbox" aria-label={label} tabIndex={-1} aria-activedescendant={`mt-dd-${active}`}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown") { e.preventDefault(); setActive((i) => Math.min(i + 1, options.length - 1)) }
            else if (e.key === "ArrowUp") { e.preventDefault(); setActive((i) => Math.max(i - 1, 0)) }
            else if (e.key === "Home") { e.preventDefault(); setActive(0) }
            else if (e.key === "End") { e.preventDefault(); setActive(options.length - 1) }
            else if (e.key === "Enter" || e.key === " ") { e.preventDefault(); pick(active) }
            else if (e.key === "Escape" || e.key === "Tab") { e.preventDefault(); e.stopPropagation(); setOpen(false); (root.current?.querySelector("button") as HTMLElement | null)?.focus() }
          }}>
          {options.map((o, i) => (
            <li key={o.value} id={`mt-dd-${i}`} role="option" aria-selected={o.value === value} data-active={i === active} onMouseEnter={() => setActive(i)} onClick={() => pick(i)}>
              {o.icon}<span>{o.label}</span>{o.value === value && <Icon name="check" className="mt-ai mt-dd-tick" />}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`
const logos = new Map<string, string>()

/** The organisation's banner logo that Maester embeds from Entra company branding, as a blob URL made from the
 *  image's decoded bytes. Only a base64 data URI of a raster or SVG image is used, so the report never loads a
 *  remote image and no text from the result reaches the page as markup. */
export function tenantLogo(result: Record<string, unknown> | undefined): string | undefined {
  const banner = (result?.TenantLogos as Record<string, unknown> | undefined)?.Banner
  if (typeof banner !== "string") return undefined
  if (logos.has(banner)) return logos.get(banner)
  // The type is the one Graph sent, often image/*. The browser works out a raster format from the bytes, but an
  // SVG needs its own type, so it is told by its first character.
  const match = /^data:image\/[\w.+*-]+;base64,([A-Za-z0-9+/=\s]+)$/i.exec(banner)
  if (!match) return undefined
  try {
    const bytes = Uint8Array.from(atob(match[1].replace(/\s/g, "")), (c) => c.charCodeAt(0))
    const type = /^\s*</.test(String.fromCharCode(...bytes.slice(0, 64))) ? "image/svg+xml" : "image/png"
    const url = URL.createObjectURL(new Blob([bytes], { type }))
    logos.set(banner, url)
    return url
  } catch {
    return undefined
  }
}

export const formatDate = (iso: string, withTime = false) => {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleString(undefined, withTime ? { dateStyle: "medium", timeStyle: "short" } : { day: "numeric", month: "short", year: "numeric" })
}
