import { useMemo, useState } from "react"
import { ExternalLink, Search } from "lucide-react"
import { Link } from "@/lib/router"
import { useTenant } from "@/context/TenantContext"

interface AssetRecord {
    System: string
    AnchorKind: string
    Type: string
    Id?: string | null
    DisplayName?: string | null
    PortalLink?: string | null
    Tests?: string[]
    Sources?: string[]
}

const anchorKindStyles: Record<string, string> = {
    Instance: "bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300",
    Singleton: "bg-purple-50 text-purple-700 dark:bg-purple-950 dark:text-purple-300",
    Surface: "bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-300",
    Collection: "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-300",
    External: "bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300",
}

const anchorKindDescriptions: Record<string, string> = {
    Instance: "A single addressable object with its own id (a policy, user, group, service principal). Usually has a portal deep link.",
    Singleton: "A tenant-level configuration resource with no id — the Graph URI itself is the identity.",
    Surface: "A portal settings page a check points to without addressing a specific object.",
    Collection: "A collection read (users, servicePrincipals) — the data set was touched, not a specific member.",
    External: "An asset outside Microsoft Graph, identified by its API path (GitHub org/repo, Azure DevOps organization).",
    Unknown: "An object a check referenced without an id, so it cannot be addressed or linked.",
}

// Only https links are rendered: a javascript: or data: url in an href runs script on click.
function safePortalLink(link?: string | null) {
    return link && /^https:\/\//i.test(link) ? link : null
}

function AnchorKindBadge({ kind }: { kind: string }) {
    return (
        <span
            title={anchorKindDescriptions[kind]}
            className={
                "inline-flex items-center rounded px-2 py-0.5 text-xs font-medium " +
                (anchorKindStyles[kind] || anchorKindStyles.Collection)
            }
        >
            {kind}
        </span>
    )
}

// Highest severity wins, so a single Critical check is not hidden behind a pile of Info ones.
const severityOrder = ["Critical", "High", "Medium", "Low", "Info"]

const severityStyles: Record<string, string> = {
    Critical: "bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300",
    High: "bg-red-50 text-red-700 dark:bg-red-950 dark:text-red-300",
    Medium: "bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-300",
    Low: "bg-green-50 text-green-700 dark:bg-green-950 dark:text-green-300",
    Info: "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-300",
}

function highestSeverity(severities: string[]) {
    return severityOrder.find((s) => severities.includes(s))
}

interface TestInfo {
    Severity?: string
    Result?: string
}

function ChecksCell({
    asset,
    testIndex,
}: {
    asset: AssetRecord
    testIndex: Map<string, TestInfo>
}) {
    const tests = asset.Tests || []
    const severities = tests
        .map((t) => testIndex.get(t)?.Severity)
        .filter(Boolean) as string[]
    const top = highestSeverity(severities)

    return (
        <td className="whitespace-nowrap px-4 py-3 text-sm">
            <div className="flex items-center gap-2">
                <span className="font-medium text-gray-900 tabular-nums dark:text-gray-100">
                    {tests.length}
                </span>
                {top && (
                    <span
                        title={`Highest severity of the ${tests.length} referencing check(s)`}
                        className={
                            "inline-flex items-center rounded px-2 py-0.5 text-xs font-medium " +
                            severityStyles[top]
                        }
                    >
                        {top}
                    </span>
                )}
            </div>
        </td>
    )
}

function ResultsCell({
    asset,
    testIndex,
}: {
    asset: AssetRecord
    testIndex: Map<string, TestInfo>
}) {
    const tests = asset.Tests || []
    const passed = tests.filter((t) => testIndex.get(t)?.Result === "Passed").length
    const failed = tests.filter((t) => testIndex.get(t)?.Result === "Failed").length
    // Skipped/Error/NotRun checks are neither, so they are only reflected in the Checks count.
    const other = tests.length - passed - failed

    return (
        <td className="whitespace-nowrap px-4 py-3 text-sm">
            <div className="flex items-center gap-2 tabular-nums">
                <span
                    title={`${passed} passed check(s)`}
                    className="inline-flex items-center rounded bg-green-50 px-2 py-0.5 text-xs font-medium text-green-700 dark:bg-green-950 dark:text-green-300"
                >
                    {passed} passed
                </span>
                <span
                    title={`${failed} failed check(s)`}
                    className="inline-flex items-center rounded bg-red-50 px-2 py-0.5 text-xs font-medium text-red-700 dark:bg-red-950 dark:text-red-300"
                >
                    {failed} failed
                </span>
                {other > 0 && (
                    <span
                        title={`${other} check(s) skipped, not run or in error`}
                        className="inline-flex items-center rounded bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-600 dark:bg-gray-800 dark:text-gray-300"
                    >
                        {other} other
                    </span>
                )}
            </div>
        </td>
    )
}

// A record is "referenced" when a check pointed at it, either through the objects the test
// passed to Add-MtTestResultDetail or through a portal deep link in its result. Everything else
// comes from the session request caches and only records that the run read that resource.
const referencedSources = ["GraphObjects", "Markdown"]

function isReferencedByCheck(asset: AssetRecord) {
    return (asset.Sources || []).some((source) => referencedSources.includes(source))
}

type TabId = "referenced" | "touched"

export default function AssetsPage() {
    const { selectedTenant: testResults } = useTenant()
    const assets: AssetRecord[] = useMemo(
        () => (Array.isArray(testResults.AssetInventory) ? testResults.AssetInventory : []),
        [testResults]
    )

    const [tab, setTab] = useState<TabId>("referenced")
    const [search, setSearch] = useState("")
    const [systemFilter, setSystemFilter] = useState("All")
    const [typeFilter, setTypeFilter] = useState("All")

    const testIndex = useMemo(() => {
        const map = new Map<string, TestInfo>()
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        for (const test of (testResults.Tests || []) as any[]) {
            if (test?.Id) map.set(test.Id, { Severity: test.Severity, Result: test.Result })
        }
        return map
    }, [testResults])

    const tabAssets = useMemo(
        () => ({
            referenced: assets.filter(isReferencedByCheck),
            touched: assets.filter((a) => !isReferencedByCheck(a)),
        }),
        [assets]
    )

    const scoped = tabAssets[tab]

    const systems = useMemo(
        () => ["All", ...Array.from(new Set(scoped.map((a) => a.System))).sort()],
        [scoped]
    )

    // Cache records carry no per-test attribution, so the column would read "run-level" for
    // every row of the Data touched tab.
    const showReferencedBy = tab === "referenced"

    // The system filter is per tab, so fall back to All when the active tab has no such system.
    const activeSystemFilter = systems.includes(systemFilter) ? systemFilter : "All"

    const types = useMemo(() => {
        const inSystem = scoped.filter(
            (a) => activeSystemFilter === "All" || a.System === activeSystemFilter
        )
        const counts = new Map<string, number>()
        for (const a of inSystem) counts.set(a.Type, (counts.get(a.Type) || 0) + 1)
        return Array.from(counts.entries()).sort((a, b) => a[0].localeCompare(b[0]))
    }, [scoped, activeSystemFilter])

    const activeTypeFilter = types.some(([type]) => type === typeFilter) ? typeFilter : "All"

    const filtered = useMemo(() => {
        const term = search.trim().toLowerCase()
        return scoped.filter((a) => {
            if (activeSystemFilter !== "All" && a.System !== activeSystemFilter) return false
            if (activeTypeFilter !== "All" && a.Type !== activeTypeFilter) return false
            if (!term) return true
            return [a.Type, a.Id, a.DisplayName, ...(a.Tests || [])]
                .filter(Boolean)
                .some((v) => String(v).toLowerCase().includes(term))
        })
    }, [scoped, search, activeSystemFilter, activeTypeFilter])

    if (assets.length === 0) {
        return (
            <div className="max-w-4xl">
                <h1 className="mb-6 text-2xl font-semibold text-gray-900 dark:text-white">
                    Asset Inventory
                </h1>
                <p className="text-gray-500 dark:text-gray-400">
                    No asset inventory is available in this report. Run{" "}
                    <code className="rounded bg-gray-100 px-1 py-0.5 font-mono text-sm dark:bg-gray-800">
                        Invoke-Maester -IncludeAssetInventory
                    </code>{" "}
                    to collect the objects involved in each check.
                </p>
            </div>
        )
    }

    return (
        <div className="max-w-6xl">
            <h1 className="mb-2 text-2xl font-semibold text-gray-900 dark:text-white">
                Asset Inventory
            </h1>
            <p className="mb-6 text-sm text-gray-500 dark:text-gray-400">
                {tab === "referenced"
                    ? "Objects that a check pointed at, with the checks that reference them."
                    : "Resources the run read while collecting data, without per-check attribution."}
            </p>

            {/* Tabs */}
            <div className="mb-4 flex gap-6 border-b border-gray-200 dark:border-gray-700">
                {(
                    [
                        { id: "referenced", label: "Referenced by checks" },
                        { id: "touched", label: "Data touched" },
                    ] as { id: TabId; label: string }[]
                ).map(({ id, label }) => (
                    <button
                        key={id}
                        onClick={() => setTab(id)}
                        className={
                            "-mb-px border-b-2 px-1 pb-3 text-sm font-medium transition-colors " +
                            (tab === id
                                ? "border-orange-500 text-orange-600 dark:text-orange-400"
                                : "border-transparent text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200")
                        }
                    >
                        {label}
                        <span className="ml-2 text-xs text-gray-400">{tabAssets[id].length}</span>
                    </button>
                ))}
            </div>

            {/* Filters */}
            <div className="mb-4 flex flex-wrap items-center gap-3">
                <div className="relative">
                    <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                    <input
                        type="text"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        placeholder="Search by name, id, type or test..."
                        className="w-72 rounded-md border border-gray-200 bg-white py-2 pl-9 pr-3 text-sm text-gray-900 placeholder-gray-400 focus:border-orange-500 focus:outline-none dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100"
                    />
                </div>
                <div className="flex flex-wrap gap-1">
                    {systems.map((system) => (
                        <button
                            key={system}
                            onClick={() => setSystemFilter(system)}
                            className={
                                "rounded-md px-3 py-1.5 text-sm font-medium transition-colors " +
                                (activeSystemFilter === system
                                    ? "bg-orange-50 text-orange-600 dark:bg-orange-950 dark:text-orange-400"
                                    : "text-gray-600 hover:bg-gray-100 dark:text-gray-400 dark:hover:bg-gray-800")
                            }
                        >
                            {system}
                            {system !== "All" && (
                                <span className="ml-1.5 text-xs text-gray-400">
                                    {scoped.filter((a) => a.System === system).length}
                                </span>
                            )}
                        </button>
                    ))}
                </div>
                <select
                    value={activeTypeFilter}
                    onChange={(e) => setTypeFilter(e.target.value)}
                    className="rounded-md border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 focus:border-orange-500 focus:outline-none dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100"
                >
                    <option value="All">All types ({types.length})</option>
                    {types.map(([type, count]) => (
                        <option key={type} value={type}>
                            {type} ({count})
                        </option>
                    ))}
                </select>
            </div>

            <div className="rounded-md border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
                <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                        <thead className="bg-gray-50 dark:bg-gray-800">
                            <tr>
                                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                                    System
                                </th>
                                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                                    Type
                                </th>
                                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                                    Object
                                </th>
                                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                                    Kind
                                </th>
                                {showReferencedBy && (
                                    <>
                                        <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                                            Checks
                                        </th>
                                        <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                                            Results
                                        </th>
                                        <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                                            Referenced by
                                        </th>
                                    </>
                                )}
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                            {filtered.map((asset, index) => (
                                <tr key={`${asset.System}-${asset.Type}-${asset.Id}-${index}`}>
                                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-500 dark:text-gray-400">
                                        {asset.System}
                                    </td>
                                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                                        {asset.Type}
                                    </td>
                                    <td className="px-4 py-3 text-sm">
                                        <div className="flex flex-col">
                                            {safePortalLink(asset.PortalLink) ? (
                                                <a
                                                    href={safePortalLink(asset.PortalLink)!}
                                                    target="_blank"
                                                    rel="noopener noreferrer"
                                                    className="inline-flex items-center gap-1 font-medium text-orange-600 hover:underline dark:text-orange-400"
                                                >
                                                    {asset.DisplayName || asset.Id || asset.Type}
                                                    <ExternalLink className="h-3 w-3 shrink-0" />
                                                </a>
                                            ) : (
                                                <span className="font-medium text-gray-900 dark:text-gray-100">
                                                    {asset.DisplayName || asset.Id || "—"}
                                                </span>
                                            )}
                                            {asset.Id && asset.DisplayName && (
                                                <span className="mt-0.5 font-mono text-xs text-gray-400 dark:text-gray-500">
                                                    {asset.Id}
                                                </span>
                                            )}
                                        </div>
                                    </td>
                                    <td className="whitespace-nowrap px-4 py-3">
                                        <AnchorKindBadge kind={asset.AnchorKind} />
                                    </td>
                                    {showReferencedBy && <ChecksCell asset={asset} testIndex={testIndex} />}
                                    {showReferencedBy && <ResultsCell asset={asset} testIndex={testIndex} />}
                                    {showReferencedBy && (
                                        <td className="px-4 py-3 text-sm">
                                            {asset.Tests && asset.Tests.length > 0 ? (
                                                <div className="flex max-w-xs flex-wrap gap-1">
                                                    {asset.Tests.map((testId) => (
                                                        <Link
                                                            key={testId}
                                                            to={`/${encodeURIComponent(testId)}`}
                                                            className="inline-flex items-center rounded bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700 dark:bg-gray-800 dark:text-gray-300"
                                                        >
                                                            {testId}
                                                        </Link>
                                                    ))}
                                                </div>
                                            ) : (
                                                <span className="text-xs text-gray-400 dark:text-gray-500">
                                                    run-level
                                                </span>
                                            )}
                                        </td>
                                    )}
                                </tr>
                            ))}
                            {filtered.length === 0 && (
                                <tr>
                                    <td colSpan={showReferencedBy ? 7 : 4} className="px-4 py-8 text-center text-sm text-gray-500 dark:text-gray-400">
                                        No assets match the current filter.
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    )
}
