// What a run is about, for the report's title, top bar and footer. A run that connected to Microsoft Graph is about
// its tenant; a run that connected only to Active Directory is about its domain; a run of local tests is about
// neither, and the report names no subject rather than a placeholder.

import type { Model } from "./model"

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Raw = any

// 3.0 writes "TenantName (not connected to Graph)" and the like when Graph is not connected. They are not names.
const PLACEHOLDER = /\(not connected to [^)]*\)\s*$/i

export function scrubPlaceholders(result: Raw): Raw {
  if (!result || typeof result !== "object") return result
  const out = { ...result }
  for (const key of ["TenantName", "TenantId", "Account"]) if (typeof out[key] === "string" && PLACEHOLDER.test(out[key])) out[key] = null
  return out
}

export type Subject = { name: string; kind: "tenant" | "domain" } | null

export function runSubject(result: Raw): Subject {
  const tenant = typeof result?.TenantName === "string" ? result.TenantName.trim().replace(/\.+$/, "") : ""
  if (tenant) return { name: tenant, kind: "tenant" }
  // Connect-Maester records Active Directory as "corp.contoso.com (dc01.corp.contoso.com)".
  const ad = (Array.isArray(result?.ConnectionSummary) ? result.ConnectionSummary : [])
    .find((c: Raw) => c?.Service === "Active Directory" && c?.Status === "Connected" && c?.Details)
  const domain = ad ? String(ad.Details).replace(/\s*\(.*\)\s*$/, "").trim() : ""
  if (domain) return { name: domain, kind: "domain" }
  return null
}

export interface Heading {
  /** Above the title, before the date. */
  eyebrow: string
  /** The title, given the pass rate: null when no test that ran was scored. */
  title: (rate: number | null) => string
  /** The name in the top bar, or null for none. */
  bar: string | null
  /** What the footer says the report holds data from. */
  holds: string
}

// "Maester report", not "Security report": a run can hold tests of any kind. A run without a subject names none.
export function reportHeading(model: Model): Heading {
  const subject = model.subject
  if (subject) return {
    eyebrow: "Maester report",
    title: (rate) => (rate === null ? `No check of ${subject.name} gave a pass or fail` : `${subject.name} passed ${rate}% of the checks that ran`),
    bar: subject.name,
    holds: subject.name,
  }
  return {
    eyebrow: "Maester report",
    title: (rate) => (rate === null ? "No check gave a pass or fail" : `${rate}% of the checks that ran passed`),
    bar: null,
    holds: "the systems its tests read",
  }
}
