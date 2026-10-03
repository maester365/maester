import { lazy, Suspense, useCallback, useMemo, useState } from "react"
import { ExternalLink } from "lucide-react"
import { MagnifyingGlassIcon } from "@heroicons/react/24/solid"
import { useTenant } from "@/context/TenantContext"
import {
    Card,
    MultiSelect,
    MultiSelectItem,
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeaderCell,
    TableRow,
    TextInput,
} from "@/components/ui/report"

const ResultInfoSheet = lazy(() => import("@/components/ResultInfoSheet"))

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

function ownValue(map: Record<string, string>, key: string) {
    return Object.prototype.hasOwnProperty.call(map, key) ? map[key] : undefined
}

function AnchorKindBadge({ kind }: { kind: string }) {
    return (
        <span
            title={ownValue(anchorKindDescriptions, kind)}
            className={
                "inline-flex items-center rounded px-2 py-0.5 text-xs font-medium " +
                (ownValue(anchorKindStyles, kind) || anchorKindStyles.Collection)
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
        <TableCell className="whitespace-nowrap text-sm">
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
        </TableCell>
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
        <TableCell className="whitespace-nowrap text-sm">
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
        </TableCell>
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


// eslint-disable-next-line @typescript-eslint/no-explicit-any
type TestResult = any

export default function AssetsPage() {
    const { selectedTenant: testResults } = useTenant()
    const assets: AssetRecord[] = useMemo(
        () => (Array.isArray(testResults.AssetInventory) ? testResults.AssetInventory : []),
        [testResults]
    )

    const [tab, setTab] = useState<TabId>("referenced")
    const [search, setSearch] = useState("")
    const [systemFilter, setSystemFilter] = useState("All")
    const [typeFilter, setTypeFilter] = useState<string[]>([])

    // The checks of the clicked asset, shown in the result sheet without leaving this page.
    const [sheetTests, setSheetTests] = useState<TestResult[]>([])
    const [sheetIndex, setSheetIndex] = useState(-1)
    const [isSheetOpen, setIsSheetOpen] = useState(false)

    const allTests: TestResult[] = useMemo(() => testResults.Tests || [], [testResults])

    const testIndex = useMemo(() => {
        const map = new Map<string, TestInfo>()
        for (const test of allTests) {
            if (test?.Id && !map.has(test.Id)) map.set(test.Id, { Severity: test.Severity, Result: test.Result })
        }
        return map
    }, [allTests])

    const openTest = useCallback(
        (asset: AssetRecord, testId: string) => {
            // Data-driven checks share one id across several results, so list every result of the asset's checks.
            const ids = new Set(asset.Tests || [])
            const tests = allTests.filter((test) => ids.has(test?.Id))
            const index = tests.findIndex((test) => test.Id === testId)
            if (index === -1) return
            setSheetTests(tests)
            setSheetIndex(index)
            setIsSheetOpen(true)
        },
        [allTests]
    )

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

    // Types selected on another tab or system that do not exist here are ignored rather than hiding every row.
    const activeTypeFilter = typeFilter.filter((type) => types.some(([t]) => t === type))

    const filtered = useMemo(() => {
        const term = search.trim().toLowerCase()
        return scoped.filter((a) => {
            if (activeSystemFilter !== "All" && a.System !== activeSystemFilter) return false
            if (activeTypeFilter.length > 0 && !activeTypeFilter.includes(a.Type)) return false
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
        <div>
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
                        onClick={() => {
                            setTab(id)
                        }}
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

            <Card>
                {/* Filters */}
                <div className="mb-4 flex flex-wrap items-center gap-2">
                    <TextInput
                        icon={MagnifyingGlassIcon}
                        value={search}
                        onChange={(e) => {
                            setSearch(e.target.value)
                        }}
                        placeholder="Search by name, id, type or test..."
                        className="min-w-[16rem] flex-1"
                    />
                    <MultiSelect
                        value={activeTypeFilter}
                        onValueChange={setTypeFilter}
                        placeholder={`Type (${types.length})`}
                        className="min-w-[16rem] flex-1"
                    >
                        {types.map(([type, count]) => (
                            <MultiSelectItem key={type} value={type}>
                                {`${type} (${count})`}
                            </MultiSelectItem>
                        ))}
                    </MultiSelect>
                    <div className="flex flex-wrap gap-1">
                        {systems.map((system) => (
                            <button
                                key={system}
                                onClick={() => {
                                    setSystemFilter(system)
                                }}
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
                </div>

                <Table className="mt-2 w-full">
                    <TableHead>
                        <TableRow>
                            <TableHeaderCell>System</TableHeaderCell>
                            <TableHeaderCell>Type</TableHeaderCell>
                            <TableHeaderCell className="w-full">Object</TableHeaderCell>
                            <TableHeaderCell>Kind</TableHeaderCell>
                            {showReferencedBy && (
                                <>
                                    <TableHeaderCell>Checks</TableHeaderCell>
                                    <TableHeaderCell>Results</TableHeaderCell>
                                    <TableHeaderCell>Referenced by</TableHeaderCell>
                                </>
                            )}
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {filtered.map((asset, index) => {
                            const portalLink = safePortalLink(asset.PortalLink)
                            return (
                                <TableRow
                                    key={`${asset.System}-${asset.Type}-${asset.Id}-${index}`}
                                    className="transition-colors hover:bg-gray-50 dark:hover:bg-gray-800/50"
                                >
                                    <TableCell className="whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                                        {asset.System}
                                    </TableCell>
                                    <TableCell className="whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                        {asset.Type}
                                    </TableCell>
                                    <TableCell className="whitespace-normal break-words text-sm">
                                        <div className="flex flex-col">
                                            {portalLink ? (
                                                <a
                                                    href={portalLink}
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
                                                <span className="mt-0.5 break-all font-mono text-xs text-gray-400 dark:text-gray-500">
                                                    {asset.Id}
                                                </span>
                                            )}
                                        </div>
                                    </TableCell>
                                    <TableCell className="whitespace-nowrap">
                                        <AnchorKindBadge kind={asset.AnchorKind} />
                                    </TableCell>
                                    {showReferencedBy && <ChecksCell asset={asset} testIndex={testIndex} />}
                                    {showReferencedBy && <ResultsCell asset={asset} testIndex={testIndex} />}
                                    {showReferencedBy && (
                                        <TableCell className="text-sm">
                                            {asset.Tests && asset.Tests.length > 0 ? (
                                                <div className="flex min-w-[8rem] flex-wrap gap-1">
                                                    {asset.Tests.map((testId) => (
                                                        <button
                                                            key={testId}
                                                            type="button"
                                                            onClick={() => openTest(asset, testId)}
                                                            title="Show the check result"
                                                            className="inline-flex items-center whitespace-nowrap rounded bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700 transition-colors hover:bg-orange-50 hover:text-orange-600 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-orange-950 dark:hover:text-orange-400"
                                                        >
                                                            {testId}
                                                        </button>
                                                    ))}
                                                </div>
                                            ) : (
                                                <span className="text-xs text-gray-400 dark:text-gray-500">
                                                    run-level
                                                </span>
                                            )}
                                        </TableCell>
                                    )}
                                </TableRow>
                            )
                        })}
                        {filtered.length === 0 && (
                            <TableRow>
                                <td colSpan={showReferencedBy ? 7 : 4} className="p-4 py-8 text-center text-sm text-gray-500 dark:text-gray-400">
                                    No assets match the current filter.
                                </td>
                            </TableRow>
                        )}
                    </TableBody>
                </Table>
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
