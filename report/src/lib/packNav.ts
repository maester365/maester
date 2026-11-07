// A pack's menu in the report: the manifest's Report.Navigation, carried in the result as JSON text (see
// Get-MtResultPack). Each entry is a row (Title) or a section heading (Section) that opens one of the report's
// built-in views; any entry can hold Items, to any depth. A pack never brings code into the report.

export const PACK_VIEWS = ["pack", "tests", "plan", "attachment", "guide", "about"] as const
export type PackView = (typeof PACK_VIEWS)[number]

export interface NavEntry {
  Id?: string
  Title?: string
  Section?: string
  View?: string
  Attachment?: string
  Expand?: string[]
  GroupBy?: string[]
  Result?: string
  Filter?: Record<string, string | string[]>
  Page?: string
  Items?: NavEntry[]
}

export interface GuideStep { Text?: string; Command?: string }
export interface PackGuide {
  Summary?: string
  Prerequisites?: GuideStep[]
  Connect?: { Steps?: GuideStep[]; Notes?: string[]; More?: string }
  Run?: { Commands?: GuideStep[]; Notes?: string[]; Options?: { Name: string; Default?: string; Text?: string }[]; More?: string }
  AppOnly?: { Supported?: boolean; Text?: string; Command?: string; More?: string; OtherRoles?: string[] }
  Links?: { Text: string; Url: string }[]
}

/** Lower case with dashes, for a page's part of a link. */
export const slug = (s: string) => s.toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "page"

// The result carries both as JSON text; a dev sample may give the parsed value.
function parse<T>(value: unknown): T | null {
  if (value === null || value === undefined || value === "") return null
  if (typeof value !== "string") return value as T
  try { return JSON.parse(value) as T } catch { return null }
}

const isEntry = (e: unknown): e is NavEntry => !!e && typeof e === "object" && !Array.isArray(e) && (typeof (e as NavEntry).Title === "string" || typeof (e as NavEntry).Section === "string")
const texts = (v: unknown) => (Array.isArray(v) ? v : v === undefined || v === null ? [] : [v]).filter((x): x is string => typeof x === "string" && !!x)

// Keeps only entries the report can draw, so a pack written for a newer report still gets a menu.
function clean(list: unknown): NavEntry[] {
  return (Array.isArray(list) ? list : []).filter(isEntry).flatMap((e) => {
    if (e.View && !(PACK_VIEWS as readonly string[]).includes(e.View)) return []
    const items = clean(e.Items)
    if (!e.View && !items.length) return []
    return [{ ...e, Expand: texts(e.Expand), GroupBy: texts(e.GroupBy), Items: items }]
  })
}

export function readNavigation(value: unknown): NavEntry[] | null {
  const list = parse<unknown>(value)
  if (!Array.isArray(list)) return null
  const entries = clean(list)
  return entries.length ? entries : null
}

export function readGuide(value: unknown): PackGuide | null {
  const g = parse<PackGuide>(value)
  return g && typeof g === "object" && !Array.isArray(g) ? g : null
}

/** The values a test has for one of its Fields: a list, one value, or none. */
export function fieldValues(fields: Record<string, unknown> | undefined, name: string): string[] {
  const v = fields?.[name]
  return texts(v).map(String)
}
