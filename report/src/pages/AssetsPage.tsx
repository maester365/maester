import { lazy, Suspense, useCallback, useMemo, useState, type ReactNode } from "react"
import { ChevronRight, ExternalLink, Layers, ListChevronsDownUp, ListChevronsUpDown, X } from "lucide-react"
import { MagnifyingGlassIcon } from "@heroicons/react/24/solid"
import { useTenant } from "@/context/TenantContext"
import { Card, TextInput } from "@/components/ui/report"
import { assetIconUri } from "@/lib/assetIcons"
import { assetTypePriority, getAssetTypeInfo, type AssetTypeInfo } from "@/lib/assetTypes"
import { cn } from "@/lib/utils"

const ResultInfoSheet = lazy(() => import("@/components/ResultInfoSheet"))

// The html report embeds a slim record (Referenced flag); older reports and the json output carry
// the full record with its Sources list.
interface AssetRecord {
    System: string
    Type: string
    Id?: string | null
    DisplayName?: string | null
    PortalLink?: string | null
    Tests?: string[] | null
    Referenced?: boolean
    Sources?: string[] | null
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
    record: AssetRecord
    info: AssetTypeInfo
    label: string
    portalLink: string | null
    referenced: boolean
    checks: CheckInfo[]
    failed: number
    failSeverity: number
    maxSeverity: number
}

const severities = ["Critical", "High", "Medium", "Low", "Info"] as const
const severityRank: Record<string, number> = { Critical: 5, High: 4, Medium: 3, Low: 2, Info: 1 }

const severityBadge: Record<string, string> = {
    Critical: "bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300",
    High: "bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300",
    Medium: "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300",
    Low: "bg-green-100 text-green-700 dark:bg-green-950 dark:text-green-300",
    Info: "bg-gray-100 text-gray-600 dark:bg-zinc-800 dark:text-zinc-300",
}
const severityDot: Record<string, string> = {
    Critical: "bg-rose-700",
    High: "bg-red-600",
    Medium: "bg-amber-500",
    Low: "bg-green-600",
    Info: "bg-gray-500",
}
const statusBadge: Record<Status, string> = {
    Failed: "bg-red-50 text-red-700 dark:bg-red-950 dark:text-red-300",
    Passed: "bg-green-50 text-green-700 dark:bg-green-950 dark:text-green-300",
    Other: "bg-gray-100 text-gray-600 dark:bg-zinc-800 dark:text-zinc-300",
}
const statusMark: Record<Status, string> = { Failed: "✕", Passed: "✓", Other: "•" }

const referencedSources = ["GraphObjects", "Markdown"]

function lookup<T>(map: Record<string, T>, key: string | undefined | null): T | undefined {
    return key && Object.prototype.hasOwnProperty.call(map, key) ? map[key] : undefined
}

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
    const style = lookup(severityBadge, severity)
    return style ? <Pill className={style}>{severity}</Pill> : null
}

function TypeIcon({ info, size = 20 }: { info: AssetTypeInfo; size?: number }) {
    return <img src={assetIconUri(info.icon)} alt="" width={size} height={size} className="shrink-0" />
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
                    onClick={() => onToggle(option)}
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

export default function AssetsPage() {
    const { selectedTenant: testResults } = useTenant()
    const records: AssetRecord[] = useMemo(
        () => (Array.isArray(testResults.AssetInventory) ? testResults.AssetInventory : []),
        [testResults]
    )
    const allTests: TestResult[] = useMemo(() => testResults.Tests || [], [testResults])

    const [tab, setTab] = useState<TabId>("referenced")
    const [search, setSearch] = useState("")
    const [tileFilter, setTileFilter] = useState<Set<string>>(new Set())
    const [severityFilter, setSeverityFilter] = useState<Set<string>>(new Set())
    const [resultFilter, setResultFilter] = useState<"All" | "Failed" | "Passed">("All")
    const [grouped, setGrouped] = useState(false)
    const [sort, setSort] = useState<{ column: SortColumn; direction: 1 | -1 } | null>(null)
    const [open, setOpen] = useState<Set<string>>(new Set())
    const [closedGroups, setClosedGroups] = useState<Set<string>>(new Set())

    const [sheetTests, setSheetTests] = useState<TestResult[]>([])
    const [sheetIndex, setSheetIndex] = useState(-1)
    const [isSheetOpen, setIsSheetOpen] = useState(false)

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
                const info = getAssetTypeInfo(record.System, record.Type)
                const checks = (record.Tests || [])
                    .map((id) => checksById.get(id) ?? { id, title: "", status: "Other" as Status, result: "", severity: "" })
                    .sort(
                        (a, b) =>
                            (a.status === "Failed" ? 0 : 1) - (b.status === "Failed" ? 0 : 1) ||
                            (severityRank[b.severity] ?? 0) - (severityRank[a.severity] ?? 0) ||
                            a.id.localeCompare(b.id)
                    )
                const failedChecks = checks.filter((check) => check.status === "Failed")
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
                    failSeverity: Math.max(0, ...failedChecks.map((check) => severityRank[check.severity] ?? 0)),
                    maxSeverity: Math.max(0, ...checks.map((check) => severityRank[check.severity] ?? 0)),
                }
            }),
        [records, checksById]
    )

    const isReferencedTab = tab === "referenced"
    const scoped = useMemo(() => objects.filter((o) => o.referenced === isReferencedTab), [objects, isReferencedTab])
    // Referenced objects group by type; run-level reads span dozens of endpoints, so they group by area.
    const groupKey = useCallback((o: AffectedObject) => (isReferencedTab ? o.info.name : o.info.area), [isReferencedTab])

    // Default order: Conditional Access policies, then users, then everything else; each by the
    // most severe failed check, then the number of failed checks.
    const byPriority = useCallback(
        (a: AffectedObject, b: AffectedObject) =>
            (assetTypePriority[a.info.name] ?? 2) - (assetTypePriority[b.info.name] ?? 2) ||
            b.failSeverity - a.failSeverity ||
            b.failed - a.failed ||
            b.maxSeverity - a.maxSeverity ||
            a.info.name.localeCompare(b.info.name) ||
            a.label.localeCompare(b.label),
        []
    )

    const groups = useMemo(() => {
        const map = new Map<string, { count: number; failed: number; info: AssetTypeInfo; first: AffectedObject }>()
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

    const activeTiles = useMemo(
        () => new Set([...tileFilter].filter((name) => groups.some(([key]) => key === name))),
        [tileFilter, groups]
    )

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
            if (!sort) return byPriority(a, b)
            const sorters: Record<SortColumn, () => number> = {
                type: () => a.info.name.localeCompare(b.info.name) || a.label.localeCompare(b.label),
                object: () => a.label.localeCompare(b.label),
                severity: () => a.failSeverity - b.failSeverity || a.maxSeverity - b.maxSeverity,
                checks: () => a.failed - b.failed || a.checks.length - b.checks.length,
            }
            return sort.direction * sorters[sort.column]() || byPriority(a, b)
        }
        return scoped
            .filter((o) => {
                if (activeTiles.size > 0 && !activeTiles.has(groupKey(o))) return false
                if (
                    term &&
                    ![o.info.name, o.label, o.record.Id, o.record.Type, ...o.checks.flatMap((c) => [c.id, c.title])]
                        .filter(Boolean)
                        .some((value) => String(value).toLowerCase().includes(term))
                )
                    return false
                return visibleChecks(o).length > 0
            })
            .sort(compare)
    }, [scoped, search, activeTiles, groupKey, visibleChecks, sort, byPriority])

    const toggleIn = <T,>(set: Set<T>, value: T) => {
        const next = new Set(set)
        if (next.has(value)) next.delete(value)
        else next.add(value)
        return next
    }

    const openCheck = useCallback(
        (object: AffectedObject, checkId: string) => {
            const order = new Map(visibleChecks(object).map((c, i) => [c.id, i]))
            const tests = allTests
                .filter((test) => order.has(test?.Id))
                .sort((a, b) => (order.get(a.Id) ?? 0) - (order.get(b.Id) ?? 0))
            const index = tests.findIndex((test) => test.Id === checkId)
            if (index === -1) return
            setSheetTests(tests)
            setSheetIndex(index)
            setIsSheetOpen(true)
        },
        [allTests, visibleChecks]
    )

    const onSort = (column: SortColumn) => {
        const first: 1 | -1 = column === "severity" || column === "checks" ? -1 : 1
        if (!sort || sort.column !== column) setSort({ column, direction: first })
        else if (sort.direction === first) setSort({ column, direction: first === 1 ? -1 : 1 })
        else setSort(null)
    }

    const switchTab = (next: TabId) => {
        setTab(next)
        setTileFilter(new Set())
        setSeverityFilter(new Set())
        setResultFilter("All")
        setSort(null)
        setOpen(new Set())
    }

    const resetAll = () => {
        setTileFilter(new Set())
        setSeverityFilter(new Set())
        setResultFilter("All")
        setSearch("")
        setSort(null)
    }

    const rowKeys = isReferencedTab ? rows.map((o) => o.key) : []
    const allOpen = rowKeys.length > 0 && rowKeys.every((key) => open.has(key))
    const hasFilters = activeTiles.size > 0 || severityFilter.size > 0 || resultFilter !== "All" || search !== "" || sort !== null
    const columnCount = isReferencedTab ? 5 : 4

    if (records.length === 0) {
        return (
            <div className="max-w-4xl">
                <h1 className="mb-6 text-2xl font-semibold text-gray-900 dark:text-white">Affected objects</h1>
                <p className="text-gray-500 dark:text-gray-400">
                    This report has no affected objects. Run{" "}
                    <code className="rounded bg-gray-100 px-1 py-0.5 font-mono text-sm dark:bg-gray-800">
                        Invoke-Maester -IncludeAssetInventory
                    </code>{" "}
                    to collect the objects behind each result.
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
            onClick={() => onSort(column)}
            aria-sort={sort?.column === column ? (sort.direction === 1 ? "ascending" : "descending") : "none"}
        >
            {label}
            <span className="ml-1 text-gray-400">{sort?.column === column ? (sort.direction === 1 ? "▲" : "▼") : ""}</span>
        </th>
    )

    const renderRow = (o: AffectedObject) => {
        const isOpen = open.has(o.key)
        const checks = visibleChecks(o)
        const top = severities.find((s) => severityRank[s] === (o.failSeverity || o.maxSeverity))
        return [
            <tr
                key={o.key}
                className={cn(
                    "border-b border-gray-200 dark:border-zinc-800",
                    isReferencedTab && "cursor-pointer hover:bg-gray-50 dark:hover:bg-zinc-900"
                )}
                onClick={(event) => {
                    if (!isReferencedTab || (event.target as HTMLElement).closest("a")) return
                    setOpen(toggleIn(open, o.key))
                }}
                aria-expanded={isReferencedTab ? isOpen : undefined}
            >
                <td className="w-9 py-3 pl-3 pr-0 align-middle">
                    {isReferencedTab && (
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
            isReferencedTab && isOpen ? (
                <tr key={`${o.key}-checks`} className="border-b border-gray-200 bg-gray-50/60 dark:border-zinc-800 dark:bg-zinc-900/40">
                    <td colSpan={columnCount} className="p-0">
                        {checks.map((c) => (
                            <button
                                key={c.id}
                                type="button"
                                onClick={() => openCheck(o, c.id)}
                                title="Show the check result"
                                className="grid min-h-9 w-full grid-cols-[68px_84px_minmax(0,1fr)] items-center gap-3 border-t border-gray-200 py-1.5 pl-12 pr-4 text-left first:border-t-0 hover:bg-gray-100 lg:grid-cols-[68px_84px_150px_minmax(0,1fr)] dark:border-zinc-800 dark:hover:bg-zinc-800/60"
                            >
                                <span>
                                    <SeverityPill severity={c.severity} />
                                </span>
                                <span>
                                    <Pill className={statusBadge[c.status]}>
                                        {statusMark[c.status]} {c.result || "Unknown"}
                                    </Pill>
                                </span>
                                <span className="font-mono text-xs text-gray-500 dark:text-zinc-400">{c.id}</span>
                                <span className="col-span-3 text-sm leading-snug text-gray-800 lg:col-span-1 dark:text-zinc-200">{c.title}</span>
                            </button>
                        ))}
                    </td>
                </tr>
            ) : null,
        ]
    }

    const groupedRows = () => {
        const byGroup = new Map<string, AffectedObject[]>()
        for (const o of rows) {
            const key = groupKey(o)
            const list = byGroup.get(key)
            if (list) list.push(o)
            else byGroup.set(key, [o])
        }
        return groups.flatMap(([name, group]) => {
            const list = byGroup.get(name)
            if (!list) return []
            const closed = closedGroups.has(name)
            const failed = list.filter((o) => o.failed).length
            return [
                <tr
                    key={`group-${name}`}
                    className="cursor-pointer border-b border-gray-200 bg-gray-50 dark:border-zinc-800 dark:bg-zinc-900"
                    onClick={() => setClosedGroups(toggleIn(closedGroups, name))}
                    aria-expanded={!closed}
                >
                    <td colSpan={columnCount} className="px-3 py-2">
                        <div className="flex items-center gap-2.5 text-sm font-semibold text-gray-900 dark:text-zinc-100">
                            <ChevronRight className={cn("h-4 w-4 text-gray-400 transition-transform", !closed && "rotate-90")} />
                            <TypeIcon info={group.info} size={18} />
                            {name}
                            <span className="text-xs font-normal text-gray-500 dark:text-zinc-400">{list.length}</span>
                            {isReferencedTab && failed > 0 && (
                                <span className="text-xs font-normal text-red-600 dark:text-red-400">{failed} with failed checks</span>
                            )}
                        </div>
                    </td>
                </tr>,
                ...(closed ? [] : list.flatMap(renderRow)),
            ]
        })
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
                        onClick={() => switchTab(id)}
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

            <div className="mb-4 grid grid-cols-[repeat(auto-fill,minmax(200px,1fr))] gap-2.5">
                {groups.map(([name, group]) => (
                    <button
                        key={name}
                        type="button"
                        aria-pressed={activeTiles.has(name)}
                        title={`Show only ${name}`}
                        onClick={() => setTileFilter(toggleIn(tileFilter, name))}
                        className={cn(
                            "flex items-center gap-3 rounded-lg border px-3 py-2.5 text-left transition-colors",
                            activeTiles.has(name)
                                ? "border-orange-500 bg-orange-50 dark:border-orange-600 dark:bg-orange-950"
                                : "border-gray-200 bg-white hover:border-orange-300 dark:border-zinc-800 dark:bg-zinc-950 dark:hover:border-orange-800"
                        )}
                    >
                        <TypeIcon info={group.info} size={28} />
                        <span className="min-w-0">
                            <span className="block text-xl font-semibold leading-tight text-gray-900 dark:text-white">{group.count}</span>
                            <span className="block truncate text-xs text-gray-500 dark:text-zinc-400">{name}</span>
                            {isReferencedTab && group.failed > 0 && (
                                <span className="block text-[11px] text-red-600 dark:text-red-400">{group.failed} with failed checks</span>
                            )}
                        </span>
                    </button>
                ))}
            </div>

            <Card className="p-0">
                <div className="flex flex-wrap items-center gap-2 border-b border-gray-200 px-4 py-3 dark:border-zinc-800">
                    <TextInput
                        icon={MagnifyingGlassIcon}
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        placeholder="Search by name, id, type or check"
                        className="min-w-[14rem] flex-1"
                    />
                    {isReferencedTab && (
                        <>
                            <Segmented
                                label="Severity"
                                options={severities}
                                isOn={(s) => severityFilter.has(s)}
                                onToggle={(s) => setSeverityFilter(toggleIn(severityFilter, s))}
                                render={(s) => (
                                    <>
                                        <span className={cn("h-2 w-2 rounded-full", severityDot[s])} />
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
                    <ToggleButton on={grouped} onClick={() => setGrouped(!grouped)} icon={Layers}>
                        Group by {isReferencedTab ? "type" : "area"}
                    </ToggleButton>
                    {isReferencedTab && (
                        <ToggleButton
                            onClick={() => setOpen(allOpen ? new Set() : new Set([...open, ...rowKeys]))}
                            icon={allOpen ? ListChevronsDownUp : ListChevronsUpDown}
                        >
                            {allOpen ? "Collapse all" : "Expand all"}
                        </ToggleButton>
                    )}
                </div>

                {(activeTiles.size > 0 || hasFilters || (isReferencedTab && !sort)) && (
                    <div className="flex flex-wrap items-center gap-2 px-4 pt-2 text-xs">
                        {[...activeTiles].map((name) => (
                            <span key={name} className="inline-flex h-5 items-center gap-1 rounded bg-orange-50 px-1.5 text-orange-600 dark:bg-orange-950 dark:text-orange-400">
                                {name}
                                <button type="button" aria-label={`Remove ${name} filter`} onClick={() => setTileFilter(toggleIn(tileFilter, name))}>
                                    <X className="h-3 w-3" />
                                </button>
                            </span>
                        ))}
                        {hasFilters && (
                            <button type="button" onClick={resetAll} className="text-gray-500 hover:text-orange-600 dark:text-zinc-400">
                                Reset filters and sort
                            </button>
                        )}
                        {isReferencedTab && !sort && (
                            <span className="text-gray-400 dark:text-zinc-500">
                                Sorted by priority: Conditional Access policies, then users, then other objects, each by their most severe failed check.
                            </span>
                        )}
                    </div>
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
                        ) : grouped ? (
                            groupedRows()
                        ) : (
                            rows.flatMap(renderRow)
                        )}
                    </tbody>
                </table>
            </Card>

            <Suspense fallback={null}>
                <ResultInfoSheet
                    Item={sheetTests[sheetIndex] ?? null}
                    isOpen={isSheetOpen}
                    onClose={() => setIsSheetOpen(false)}
                    onNavigateNext={sheetIndex < sheetTests.length - 1 ? () => setSheetIndex(sheetIndex + 1) : undefined}
                    onNavigatePrevious={sheetIndex > 0 ? () => setSheetIndex(sheetIndex - 1) : undefined}
                    currentIndex={sheetIndex !== -1 ? sheetIndex + 1 : undefined}
                    totalCount={sheetTests.length}
                />
            </Suspense>
        </div>
    )
}
