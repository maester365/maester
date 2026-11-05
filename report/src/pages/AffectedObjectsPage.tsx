import { ChevronRight, ExternalLink, FunnelX, Layers, ListChevronsDownUp, ListChevronsUpDown, Search } from "lucide-react"
import { useCallback, useMemo, useState, type CSSProperties, type ReactNode } from "react"
import { useTenant } from "@/context/TenantContext"
import { useReport } from "@/components/report/ReportContext"
import { Card, TextInput } from "@/components/ui/report"
import { affectedObjectIconUri } from "@/lib/affectedObjectIcons"
import { affectedObjectTypePriority, getAffectedObjectTypeInfo, type AffectedObjectTypeInfo } from "@/lib/affectedObjectTypes"
import { cn } from "@/lib/utils"


// What a pack or test knows about the object (Add-MtAffectedObjectFact), shown when the row is expanded.
interface AffectedObjectFact {
    Name: string
    Value: string
    Tone?: string | null
    // A shared fact key (user.mfaRegistered, signIn.daysSince...) and the value as data, for summaries that read facts.
    Key?: string | null
    Raw?: boolean | number | string | string[] | null
    Source?: string | null
    AsOf?: string | null
}

type Tone = "Risk" | "Warning" | "Good" | "Info"

// The html report embeds a slim record (Referenced flag); older reports and the json output carry
// the full record with its Sources list.
interface AffectedObjectRecord {
    System: string
    Type: string
    Id?: string | null
    DisplayName?: string | null
    PortalLink?: string | null
    Tests?: string[] | null
    Referenced?: boolean
    Sources?: string[] | null
    Facts?: AffectedObjectFact[] | null
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type TestResult = any

type Status = "Failed" | "Passed" | "Other"
type TabId = "referenced" | "touched"
type SortColumn = "type" | "object" | "severity" | "checks"

interface CheckInfo {
    id: string
    title: string
    status: Status
    result: string
    severity: string
}

interface AffectedObject {
    key: string
    record: AffectedObjectRecord
    info: AffectedObjectTypeInfo
    label: string
    portalLink: string | null
    referenced: boolean
    checks: CheckInfo[]
    failed: number
    failSeverity: number
    maxSeverity: number
    facts: AffectedObjectFact[]
    risks: number
    warnings: number
}

const severities = ["Critical", "High", "Medium", "Low", "Info"] as const
// Maps rather than object literals: the keys come from report data, and Map.get never resolves
// inherited properties such as "constructor".
const severityRanks = new Map<string, number>([["Critical", 5], ["High", 4], ["Medium", 3], ["Low", 2], ["Info", 1]])
const severityRank = (severity: string | undefined) => (severity ? severityRanks.get(severity) ?? 0 : 0)

const severityBadge = new Map<string, string>([
    ["Critical", "bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300"],
    ["High", "bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300"],
    ["Medium", "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300"],
    ["Low", "bg-green-100 text-green-700 dark:bg-green-950 dark:text-green-300"],
    ["Info", "bg-gray-100 text-gray-600 dark:bg-zinc-800 dark:text-zinc-300"],
])
const severityDot = new Map<string, string>([
    ["Critical", "bg-rose-700"],
    ["High", "bg-red-600"],
    ["Medium", "bg-amber-500"],
    ["Low", "bg-green-600"],
    ["Info", "bg-gray-500"],
])
const statusBadge: Record<Status, string> = {
    Failed: "bg-red-50 text-red-700 dark:bg-red-950 dark:text-red-300",
    Passed: "bg-green-50 text-green-700 dark:bg-green-950 dark:text-green-300",
    Other: "bg-gray-100 text-gray-600 dark:bg-zinc-800 dark:text-zinc-300",
}
const statusMark: Record<Status, string> = { Failed: "✕", Passed: "✓", Other: "•" }

const toneOrder: Tone[] = ["Risk", "Warning", "Good", "Info"]
const toTone = (tone?: string | null): Tone => (toneOrder.includes(tone as Tone) ? (tone as Tone) : "Info")
const toneDot = new Map<Tone, string>([
    ["Risk", "bg-red-600"],
    ["Warning", "bg-amber-500"],
    ["Good", "bg-green-600"],
    ["Info", "bg-gray-300 dark:bg-zinc-600"],
])
const toneValue = new Map<Tone, string>([
    ["Risk", "text-red-700 dark:text-red-300"],
    ["Warning", "text-amber-800 dark:text-amber-300"],
    ["Good", "text-green-700 dark:text-green-300"],
    ["Info", "text-gray-800 dark:text-zinc-200"],
])

// The facts behind a "2 risks" badge, for its tooltip.
function factTitle(o: AffectedObject, tone: Tone) {
    return o.facts
        .filter((fact) => toTone(fact.Tone) === tone)
        .map((fact) => `${fact.Name}: ${fact.Value}`)
        .join("\n")
}

// "Zero Trust Assessment, 23 Oct 2026": where a fact comes from and when that data was read.
function factSourceLabel(fact: AffectedObjectFact) {
    const source = fact.Source || "Unknown source"
    const date = fact.AsOf ? new Date(fact.AsOf) : null
    return date && !Number.isNaN(date.getTime())
        ? `${source}, ${date.toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" })}`
        : source
}

// The distinct source labels of an object's facts, in the order they first appear.
function factSources(facts: AffectedObjectFact[]) {
    return [...new Set(facts.map(factSourceLabel))]
}

const referencedSources = ["GraphObjects", "Markdown"]


// Only https links are rendered: a javascript: or data: url in an href runs script on click.
function safePortalLink(link?: string | null) {
    return link && /^https:\/\//i.test(link) ? link : null
}

function toStatus(result: string | undefined): Status {
    return result === "Failed" || result === "Passed" ? result : "Other"
}

// One height, radius and type size for every badge on the page.
function Pill({ className, mono, title, children }: { className: string; mono?: boolean; title?: string; children: ReactNode }) {
    return (
        <span
            title={title}
            className={cn(
                "inline-flex h-5 max-w-full items-center gap-1 whitespace-nowrap rounded px-1.5 text-[11px] leading-none",
                mono ? "overflow-hidden text-ellipsis font-mono" : "font-medium",
                className
            )}
        >
            {children}
        </span>
    )
}

function SeverityPill({ severity }: { severity?: string }) {
    const style = severity ? severityBadge.get(severity) : undefined
    return style ? <Pill className={style}>{severity}</Pill> : null
}

function TypeIcon({ info, size = 20 }: { info: AffectedObjectTypeInfo; size?: number }) {
    return <img src={affectedObjectIconUri(info.icon)} alt="" width={size} height={size} className="shrink-0" />
}

function Segmented<T extends string>({ label, options, isOn, onToggle, render }: {
    label: string
    options: readonly T[]
    isOn: (option: T) => boolean
    onToggle: (option: T) => void
    render?: (option: T) => ReactNode
}) {
    return (
        <div className="inline-flex h-8 max-w-full overflow-x-auto rounded-md border border-gray-200 text-xs dark:border-zinc-700">
            <span className="flex shrink-0 items-center border-r border-gray-200 bg-gray-50 px-2 text-gray-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-400">
                {label}
            </span>
            {options.map((option) => (
                <button
                    key={option}
                    type="button"
                    aria-pressed={isOn(option)}
                    onClick={() => { onToggle(option) }}
                    className={cn(
                        "flex shrink-0 items-center gap-1.5 border-r border-gray-200 px-2.5 last:border-r-0 dark:border-zinc-700",
                        isOn(option)
                            ? "bg-orange-50 text-orange-600 dark:bg-orange-950 dark:text-orange-400"
                            : "bg-white text-gray-700 hover:bg-gray-50 dark:bg-zinc-950 dark:text-zinc-300 dark:hover:bg-zinc-900"
                    )}
                >
                    {render ? render(option) : option}
                </button>
            ))}
        </div>
    )
}

function ToggleButton({ on, onClick, icon: Icon, children }: { on?: boolean; onClick: () => void; icon: typeof Layers; children: ReactNode }) {
    return (
        <button
            type="button"
            aria-pressed={on}
            onClick={onClick}
            className={cn(
                "inline-flex h-8 items-center gap-1.5 whitespace-nowrap rounded-md border px-2.5 text-xs",
                on
                    ? "border-orange-400 bg-orange-50 text-orange-600 dark:border-orange-700 dark:bg-orange-950 dark:text-orange-400"
                    : "border-gray-200 bg-white text-gray-700 hover:bg-gray-50 dark:border-zinc-700 dark:bg-zinc-950 dark:text-zinc-300 dark:hover:bg-zinc-900"
            )}
        >
            <Icon className="h-3.5 w-3.5" />
            {children}
        </button>
    )
}

export default function AffectedObjectsPage() {
    const { selectedTenant: testResults } = useTenant()
    const records: AffectedObjectRecord[] = useMemo(
        () => (Array.isArray(testResults.AffectedObjects) ? testResults.AffectedObjects : []),
        [testResults]
    )
    const allTests: TestResult[] = useMemo(() => testResults.Tests || [], [testResults])

    const [tab, setTab] = useState<TabId>("referenced")
    const [search, setSearch] = useState("")
    const [typeTab, setTypeTab] = useState<string | null>(null)
    const [severityFilter, setSeverityFilter] = useState<Set<string>>(new Set())
    const [resultFilter, setResultFilter] = useState<"All" | "Failed" | "Passed">("All")
    const [sort, setSort] = useState<{ column: SortColumn; direction: 1 | -1 } | null>(null)
    const [open, setOpen] = useState<Set<string>>(new Set())

    const { openTest } = useReport()

    // Data-driven checks share one id across several results: a check counts as failed for an
    // object when any of its results failed.
    const checksById = useMemo(() => {
        const map = new Map<string, CheckInfo>()
        for (const test of allTests) {
            if (!test?.Id) continue
            const existing = map.get(test.Id)
            const status = toStatus(test.Result)
            if (!existing) {
                map.set(test.Id, {
                    id: test.Id,
                    title: test.Title || (test.Name?.split(": ").slice(1).join(": ") ?? test.Name ?? ""),
                    status,
                    result: test.Result ?? "",
                    severity: test.Severity ?? "",
                })
            } else if (status === "Failed" && existing.status !== "Failed") {
                existing.status = "Failed"
                existing.result = "Failed"
            }
        }
        return map
    }, [allTests])

    const objects: AffectedObject[] = useMemo(
        () =>
            records.map((record, index) => {
                const info = getAffectedObjectTypeInfo(record.System, record.Type)
                const checks = (record.Tests || [])
                    .map((id) => checksById.get(id) ?? { id, title: "", status: "Other" as Status, result: "", severity: "" })
                    .sort(
                        (a, b) =>
                            (a.status === "Failed" ? 0 : 1) - (b.status === "Failed" ? 0 : 1) ||
                            severityRank(b.severity) - severityRank(a.severity) ||
                            a.id.localeCompare(b.id)
                    )
                const failedChecks = checks.filter((check) => check.status === "Failed")
                // Report data can hold nulls whatever the type says, so each entry is checked.
                const rawFacts: (AffectedObjectFact | null | undefined)[] = Array.isArray(record.Facts) ? record.Facts : []
                const facts = rawFacts
                    .filter((fact): fact is AffectedObjectFact => Boolean(fact?.Name && fact.Value))
                    .map((fact, order) => ({ fact, order }))
                    // Risks first, then warnings, keeping the order the source gave within a tone.
                    .sort((a, b) => toneOrder.indexOf(toTone(a.fact.Tone)) - toneOrder.indexOf(toTone(b.fact.Tone)) || a.order - b.order)
                    .map(({ fact }) => fact)
                return {
                    key: `${record.System}|${record.Type}|${record.Id ?? ""}|${index}`,
                    record,
                    info,
                    label: record.DisplayName || record.Id || info.name,
                    portalLink: safePortalLink(record.PortalLink),
                    referenced:
                        typeof record.Referenced === "boolean"
                            ? record.Referenced
                            : (record.Sources || []).some((source) => referencedSources.includes(source)),
                    checks,
                    failed: failedChecks.length,
                    failSeverity: Math.max(0, ...failedChecks.map((check) => severityRank(check.severity))),
                    maxSeverity: Math.max(0, ...checks.map((check) => severityRank(check.severity))),
                    facts,
                    risks: facts.filter((fact) => toTone(fact.Tone) === "Risk").length,
                    warnings: facts.filter((fact) => toTone(fact.Tone) === "Warning").length,
                }
            }),
        [records, checksById]
    )

    const isReferencedTab = tab === "referenced"
    const scoped = useMemo(() => objects.filter((o) => o.referenced === isReferencedTab), [objects, isReferencedTab])
    // Referenced objects group by type; run-level reads span dozens of endpoints, so they group by area.
    const groupKey = useCallback((o: AffectedObject) => (isReferencedTab ? o.info.name : o.info.area), [isReferencedTab])

    // Tile order: Conditional Access policies, then users, then everything else; each by the most
    // severe failed check, then the number of failed checks.
    const byPriority = useCallback(
        (a: AffectedObject, b: AffectedObject) =>
            (affectedObjectTypePriority[a.info.name] ?? 2) - (affectedObjectTypePriority[b.info.name] ?? 2) ||
            b.failSeverity - a.failSeverity ||
            b.failed - a.failed ||
            b.maxSeverity - a.maxSeverity ||
            a.info.name.localeCompare(b.info.name) ||
            a.label.localeCompare(b.label),
        []
    )
    // Default row order: the severity shown in the Severity column (Critical first), then the most
    // failed checks. Ties keep the report's order (Array.prototype.sort is stable).
    const bySeverity = (a: AffectedObject, b: AffectedObject) =>
        (b.failSeverity || b.maxSeverity) - (a.failSeverity || a.maxSeverity) || b.failed - a.failed

    const groups = useMemo(() => {
        const map = new Map<string, { count: number; failed: number; info: AffectedObjectTypeInfo; first: AffectedObject }>()
        for (const o of scoped) {
            const key = groupKey(o)
            const group = map.get(key)
            if (!group) {
                map.set(key, { count: 1, failed: o.failed ? 1 : 0, info: o.info, first: o })
            } else {
                group.count++
                if (o.failed) group.failed++
                if (byPriority(o, group.first) < 0) group.first = o
            }
        }
        return [...map.entries()].sort(([nameA, a], [nameB, b]) =>
            isReferencedTab ? byPriority(a.first, b.first) : b.count - a.count || nameA.localeCompare(nameB)
        )
    }, [scoped, groupKey, byPriority, isReferencedTab])

    // The type tiles act as tabs: null is "All objects".
    const activeType = typeTab !== null && groups.some(([key]) => key === typeTab) ? typeTab : null

    // With a severity or result filter on, a row shows only the checks that match it.
    const visibleChecks = useCallback(
        (o: AffectedObject) =>
            !isReferencedTab || (severityFilter.size === 0 && resultFilter === "All")
                ? o.checks
                : o.checks.filter(
                      (c) =>
                          (severityFilter.size === 0 || severityFilter.has(c.severity)) &&
                          (resultFilter === "All" || c.status === resultFilter)
                  ),
        [isReferencedTab, severityFilter, resultFilter]
    )

    const rows = useMemo(() => {
        const term = search.trim().toLowerCase()
        const compare = (a: AffectedObject, b: AffectedObject) => {
            if (!sort) return bySeverity(a, b)
            let result: number
            switch (sort.column) {
                case "type":
                    result = a.info.name.localeCompare(b.info.name) || a.label.localeCompare(b.label)
                    break
                case "object":
                    result = a.label.localeCompare(b.label)
                    break
                case "severity":
                    result = -bySeverity(a, b)
                    break
                case "checks":
                    result = a.failed - b.failed || a.checks.length - b.checks.length
                    break
            }
            return sort.direction * result || bySeverity(a, b)
        }
        return scoped
            .filter((o) => {
                if (activeType !== null && groupKey(o) !== activeType) return false
                if (
                    term &&
                    ![
                        o.info.name,
                        o.label,
                        o.record.Id,
                        o.record.Type,
                        ...o.checks.flatMap((c) => [c.id, c.title]),
                        ...o.facts.flatMap((f) => [f.Name, f.Value]),
                    ]
                        .filter(Boolean)
                        .some((value) => String(value).toLowerCase().includes(term))
                )
                    return false
                // Run-level reads have no checks, so only the Referenced tab hides rows without visible checks.
                return !isReferencedTab || visibleChecks(o).length > 0
            })
            .sort(compare)
    }, [scoped, search, activeType, groupKey, visibleChecks, sort, isReferencedTab])

    const toggleIn = <T,>(set: Set<T>, value: T) => {
        const next = new Set(set)
        if (next.has(value)) next.delete(value)
        else next.add(value)
        return next
    }

    const openCheck = useCallback(
        (object: AffectedObject, checkId: string) => {
            if (visibleChecks(object).some((c) => c.id === checkId) && allTests.some((test) => test?.Id === checkId)) openTest(checkId)
        },
        [allTests, visibleChecks, openTest]
    )

    const onSort = (column: SortColumn) => {
        const first: 1 | -1 = column === "severity" || column === "checks" ? -1 : 1
        if (!sort || sort.column !== column) setSort({ column, direction: first })
        else if (sort.direction === first) setSort({ column, direction: first === 1 ? -1 : 1 })
        else setSort(null)
    }

    const switchTab = (next: TabId) => {
        setTab(next)
        setTypeTab(null)
        setSeverityFilter(new Set())
        setResultFilter("All")
        setSort(null)
        setOpen(new Set())
    }

    const resetAll = () => {
        setTypeTab(null)
        setSeverityFilter(new Set())
        setResultFilter("All")
        setSearch("")
        setSort(null)
    }

    // Referenced objects open to their checks; any object opens to its facts.
    const canOpen = (o: AffectedObject) => isReferencedTab || o.facts.length > 0
    const rowKeys = rows.filter(canOpen).map((o) => o.key)
    const allOpen = rowKeys.length > 0 && rowKeys.every((key) => open.has(key))
    const hasFilters = activeType !== null || severityFilter.size > 0 || resultFilter !== "All" || search !== "" || sort !== null
    const columnCount = isReferencedTab ? 5 : 4

    if (records.length === 0) {
        return (
            <div className="max-w-4xl">
                <h1 className="mb-6 text-2xl font-semibold text-gray-900 dark:text-white">Affected objects</h1>
                <p className="text-gray-500 dark:text-gray-400">
                    This report has no affected objects: no test recorded any, the run used{" "}
                    <code className="rounded bg-gray-100 px-1 py-0.5 font-mono text-sm dark:bg-gray-800">
                        -ExcludeAffectedObjects
                    </code>
                    , or an older version of Maester made it. Run Maester 3.0 without that switch to collect the objects
                    behind each result.
                </p>
            </div>
        )
    }

    const header = (column: SortColumn, label: string, className?: string) => (
        <th
            className={cn(
                "cursor-pointer select-none whitespace-nowrap px-3 py-2.5 text-left text-xs font-semibold text-gray-900 hover:text-orange-600 dark:text-zinc-100 dark:hover:text-orange-400",
                className
            )}
            onClick={() => { onSort(column) }}
            aria-sort={sort?.column === column ? (sort.direction === 1 ? "ascending" : "descending") : "none"}
        >
            {label}
            <span className="ml-1 text-gray-400">{sort?.column === column ? (sort.direction === 1 ? "▲" : "▼") : ""}</span>
        </th>
    )

    const renderRow = (o: AffectedObject) => {
        const isOpen = open.has(o.key)
        const expandable = canOpen(o)
        const checks = isReferencedTab ? visibleChecks(o) : []
        const sources = factSources(o.facts)
        const top = severities.find((s) => severityRank(s) === (o.failSeverity || o.maxSeverity))
        return [
            <tr
                key={o.key}
                className={cn(
                    "border-b border-gray-200 dark:border-zinc-800",
                    expandable && "cursor-pointer hover:bg-gray-50 dark:hover:bg-zinc-900"
                )}
                onClick={(event) => {
                    if (!expandable || (event.target as HTMLElement).closest("a")) return
                    setOpen(toggleIn(open, o.key))
                }}
                aria-expanded={expandable ? isOpen : undefined}
            >
                <td className="w-9 py-3 pl-3 pr-0 align-middle">
                    {expandable && (
                        <ChevronRight className={cn("h-4 w-4 text-gray-400 transition-transform", isOpen && "rotate-90")} />
                    )}
                </td>
                <td className="px-3 py-3 align-middle">
                    <div className="flex min-w-0 items-center gap-2.5">
                        <TypeIcon info={o.info} />
                        <div className="min-w-0">
                            <div className="truncate text-sm text-gray-900 dark:text-zinc-100">{o.info.name}</div>
                            <div className="truncate text-xs text-gray-400 dark:text-zinc-500">{o.info.area}</div>
                        </div>
                    </div>
                </td>
                <td className="px-3 py-3 align-middle text-sm [overflow-wrap:anywhere]">
                    {o.portalLink ? (
                        <a
                            href={o.portalLink}
                            target="_blank"
                            rel="noopener noreferrer"
                            title="Open in the admin portal"
                            className="inline-flex items-center gap-1 font-medium text-orange-600 hover:underline dark:text-orange-400"
                        >
                            {o.label}
                            <ExternalLink className="h-3 w-3 shrink-0" />
                        </a>
                    ) : (
                        <span className="font-medium text-gray-900 dark:text-zinc-100">{o.label}</span>
                    )}
                    {(o.record.DisplayName && o.record.Id) || !isReferencedTab ? (
                        <div className="truncate font-mono text-[11px] text-gray-400 dark:text-zinc-500">
                            {o.record.DisplayName && o.record.Id ? o.record.Id : o.record.Type}
                        </div>
                    ) : null}
                    {o.risks + o.warnings > 0 && (
                        <div className="mt-1 flex flex-wrap gap-1">
                            {o.risks > 0 && (
                                <Pill className="bg-red-50 text-red-700 dark:bg-red-950 dark:text-red-300" title={factTitle(o, "Risk")}>
                                    {o.risks === 1 ? "1 risk" : `${o.risks} risks`}
                                </Pill>
                            )}
                            {o.warnings > 0 && (
                                <Pill className="bg-amber-50 text-amber-800 dark:bg-amber-950 dark:text-amber-300" title={factTitle(o, "Warning")}>
                                    {o.warnings} to review
                                </Pill>
                            )}
                        </div>
                    )}
                </td>
                {isReferencedTab ? (
                    <>
                        <td className="px-3 py-3 align-middle">
                            <SeverityPill severity={top} />
                        </td>
                        <td className="px-3 py-3 align-middle">
                            <div className="flex flex-wrap gap-1">
                                {checks.map((c) => (
                                    <Pill key={c.id} mono className={statusBadge[c.status]} title={`${c.result || "Unknown"}: ${c.title}`}>
                                        {statusMark[c.status]} {c.id}
                                    </Pill>
                                ))}
                            </div>
                        </td>
                    </>
                ) : (
                    <td className="px-3 py-3 align-middle text-xs text-gray-400 dark:text-zinc-500">Run-level read</td>
                )}
            </tr>,
            expandable && isOpen ? (
                <tr key={`${o.key}-checks`} className="border-b border-gray-200 bg-gray-50/60 dark:border-zinc-800 dark:bg-zinc-900/40">
                    <td
                        colSpan={columnCount}
                        className="p-0"
                        // Size the id column to this object's longest id (mono text-xs is ~0.46rem a
                        // character), capped so very long data-driven ids truncate instead.
                        style={{ "--id-col": `${Math.min(26, Math.max(0, ...checks.map((c) => c.id.length))) * 0.46}rem` } as CSSProperties}
                    >
                        {o.facts.length > 0 && (
                            <div className={cn("py-2.5 pl-12 pr-4", checks.length > 0 && "border-b border-gray-200 dark:border-zinc-800")}>
                                <dl className="grid grid-cols-1 gap-x-4 gap-y-1.5 sm:grid-cols-[minmax(8rem,max-content)_minmax(0,1fr)]">
                                    {o.facts.map((fact, index) => {
                                        const tone = toTone(fact.Tone)
                                        // With one source and date the line below the list says it; otherwise each fact does.
                                        const ownSource = sources.length > 1 ? factSourceLabel(fact) : null
                                        return (
                                            <div key={`${fact.Name}-${index}`} className="contents">
                                                <dt className="flex items-center gap-2 text-xs text-gray-500 dark:text-zinc-400">
                                                    <span className={cn("h-2 w-2 shrink-0 rounded-full", toneDot.get(tone))} aria-hidden />
                                                    <span>{fact.Name}</span>
                                                    {tone !== "Info" && <span className="sr-only">({tone})</span>}
                                                </dt>
                                                <dd className={cn("pl-4 text-sm leading-snug [overflow-wrap:anywhere] sm:pl-0", toneValue.get(tone))}>
                                                    {fact.Value}
                                                    {ownSource && <span className="ml-2 text-[11px] text-gray-400 dark:text-zinc-500">{ownSource}</span>}
                                                </dd>
                                            </div>
                                        )
                                    })}
                                </dl>
                                {sources.length === 1 && <p className="mt-2 text-[11px] text-gray-400 dark:text-zinc-500">From {sources[0]}</p>}
                            </div>
                        )}
                        {checks.map((c) => (
                            <button
                                key={c.id}
                                type="button"
                                onClick={() => { openCheck(o, c.id) }}
                                title="Show the check result"
                                className="grid min-h-9 w-full grid-cols-[68px_84px_minmax(0,1fr)] items-center gap-3 border-t border-gray-200 py-1.5 pl-12 pr-4 text-left first:border-t-0 hover:bg-gray-100 lg:grid-cols-[68px_84px_var(--id-col)_minmax(0,1fr)] dark:border-zinc-800 dark:hover:bg-zinc-800/60"
                            >
                                <span>
                                    <SeverityPill severity={c.severity} />
                                </span>
                                <span>
                                    <Pill className={statusBadge[c.status]}>
                                        {statusMark[c.status]} {c.result || "Unknown"}
                                    </Pill>
                                </span>
                                <span className="block min-w-0 truncate font-mono text-xs text-gray-500 dark:text-zinc-400" title={c.id}>{c.id}</span>
                                <span className="col-span-3 text-sm leading-snug text-gray-800 lg:col-span-1 dark:text-zinc-200">{c.title}</span>
                            </button>
                        ))}
                    </td>
                </tr>
            ) : null,
        ]
    }

    return (
        <div>
            <h1 className="mb-1 text-2xl font-semibold text-gray-900 dark:text-white">Affected objects</h1>
            <p className="mb-6 max-w-4xl text-sm text-gray-500 dark:text-gray-400">
                The objects behind each result, so you can see what a failed check affects and fix the most severe first.
                Select an object to open it in the admin portal.
            </p>

            <div className="mb-4 flex gap-6 border-b border-gray-200 dark:border-zinc-700">
                {(
                    [
                        { id: "referenced", label: "Referenced by checks" },
                        { id: "touched", label: "Data touched" },
                    ] as { id: TabId; label: string }[]
                ).map(({ id, label }) => (
                    <button
                        key={id}
                        type="button"
                        onClick={() => { switchTab(id) }}
                        className={cn(
                            "-mb-px border-b-2 px-1 pb-3 text-sm font-medium transition-colors",
                            tab === id
                                ? "border-orange-500 text-orange-600 dark:text-orange-400"
                                : "border-transparent text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
                        )}
                    >
                        {label}
                        <span className="ml-2 text-xs text-gray-400">{objects.filter((o) => o.referenced === (id === "referenced")).length}</span>
                    </button>
                ))}
            </div>

            <div role="tablist" aria-label="Object type" className="mb-4 grid grid-cols-[repeat(auto-fill,minmax(200px,1fr))] gap-2.5">
                {[
                    {
                        key: null,
                        name: "All objects",
                        count: scoped.length,
                        failed: scoped.filter((o) => o.failed).length,
                        icon: <Layers className="h-7 w-7 shrink-0 text-orange-500" aria-hidden />,
                    },
                    ...groups.map(([name, group]) => ({
                        key: name,
                        name,
                        count: group.count,
                        failed: group.failed,
                        icon: <TypeIcon info={group.info} size={28} />,
                    })),
                ].map(({ key, name, count, failed, icon }) => {
                    const selected = activeType === key
                    return (
                        <button
                            key={name}
                            type="button"
                            role="tab"
                            aria-selected={selected}
                            title={key === null ? "Show all objects" : `Show only ${name}`}
                            onClick={() => { setTypeTab(key); setOpen(new Set()) }}
                            className={cn(
                                "flex items-center gap-3 rounded-lg border px-3 py-2.5 text-left transition-colors",
                                selected
                                    ? "border-orange-500 bg-orange-50 dark:border-orange-600 dark:bg-orange-950"
                                    : "border-gray-200 bg-white hover:border-orange-300 dark:border-zinc-800 dark:bg-zinc-950 dark:hover:border-orange-800"
                            )}
                        >
                            {icon}
                            <span className="min-w-0">
                                <span className="block text-xl font-semibold leading-tight text-gray-900 dark:text-white">{count}</span>
                                <span className="block truncate text-xs text-gray-500 dark:text-zinc-400">{name}</span>
                                {isReferencedTab && failed > 0 && (
                                    <span className="block text-[11px] text-red-600 dark:text-red-400">{failed} with failed checks</span>
                                )}
                            </span>
                        </button>
                    )
                })}
            </div>

            <Card className="p-0">
                <div className="flex flex-wrap items-center gap-2 border-b border-gray-200 px-4 py-3 dark:border-zinc-800">
                    <TextInput
                        icon={Search}
                        value={search}
                        onChange={(e) => { setSearch(e.target.value) }}
                        placeholder="Search by name, id, type or check"
                        className="min-w-[14rem] flex-1"
                    />
                    {isReferencedTab && (
                        <>
                            <Segmented
                                label="Severity"
                                options={severities}
                                isOn={(s) => severityFilter.has(s)}
                                onToggle={(s) => { setSeverityFilter(toggleIn(severityFilter, s)) }}
                                render={(s) => (
                                    <>
                                        <span className={cn("h-2 w-2 rounded-full", severityDot.get(s))} />
                                        {s}
                                    </>
                                )}
                            />
                            <Segmented
                                label="Result"
                                options={["All", "Failed", "Passed"] as const}
                                isOn={(r) => resultFilter === r}
                                onToggle={setResultFilter}
                            />
                        </>
                    )}
                    {isReferencedTab && (
                        <ToggleButton
                            onClick={() => { setOpen(allOpen ? new Set() : new Set([...open, ...rowKeys])) }}
                            icon={allOpen ? ListChevronsDownUp : ListChevronsUpDown}
                        >
                            {allOpen ? "Collapse all" : "Expand all"}
                        </ToggleButton>
                    )}
                    {hasFilters && (
                        <button
                            type="button"
                            onClick={resetAll}
                            title="Clear filters and sort"
                            aria-label="Clear filters and sort"
                            className="ml-auto inline-flex h-8 w-8 items-center justify-center rounded-md border border-orange-300 bg-orange-50 text-orange-600 hover:border-orange-500 hover:bg-orange-100 dark:border-orange-800 dark:bg-orange-950 dark:text-orange-400 dark:hover:border-orange-600 dark:hover:bg-orange-900"
                        >
                            <FunnelX className="h-4 w-4" />
                        </button>
                    )}
                </div>

                {isReferencedTab && !sort && (
                    <p className="px-4 pt-2 text-xs text-gray-400 dark:text-zinc-500">
                        Sorted by severity (Critical first), then by the number of failed checks.
                    </p>
                )}

                <table className="w-full table-fixed border-collapse">
                    <colgroup>
                        <col className="w-9" />
                        <col className={isReferencedTab ? "w-[22%]" : "w-[30%]"} />
                        <col className={isReferencedTab ? "w-[26%]" : undefined} />
                        {isReferencedTab ? (
                            <>
                                <col className="w-24" />
                                <col />
                            </>
                        ) : (
                            <col className="w-40" />
                        )}
                    </colgroup>
                    <thead className="border-b border-gray-200 dark:border-zinc-800">
                        <tr>
                            <th />
                            {header("type", "Type")}
                            {header("object", "Object")}
                            {isReferencedTab ? (
                                <>
                                    {header("severity", "Severity")}
                                    {header("checks", "Checks")}
                                </>
                            ) : (
                                <th className="px-3 py-2.5 text-left text-xs font-semibold text-gray-900 dark:text-zinc-100">Source</th>
                            )}
                        </tr>
                    </thead>
                    <tbody>
                        {rows.length === 0 ? (
                            <tr>
                                <td colSpan={columnCount} className="px-4 py-8 text-center text-sm text-gray-500 dark:text-gray-400">
                                    No objects match the current filters.
                                </td>
                            </tr>
                        ) : (
                            rows.flatMap(renderRow)
                        )}
                    </tbody>
                </table>
            </Card>

        </div>
    )
}
