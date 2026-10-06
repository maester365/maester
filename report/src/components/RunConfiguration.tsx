import type { ReactNode } from "react"
import { asArray, formatValue, formatVersion, hasRunConfiguration } from "@/lib/resultSchema"

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyRecord = Record<string, any>

function Field({ label, children, wide }: { label: string; children: ReactNode; wide?: boolean }) {
  return (
    <div className={wide ? "sm:col-span-2" : undefined}>
      <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">{label}</dt>
      <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{children}</dd>
    </div>
  )
}

function Chips({ values, empty = "None" }: { values: unknown[]; empty?: string }) {
  if (values.length === 0) return <span className="text-gray-400">{empty}</span>
  return (
    <div className="flex flex-wrap gap-1">
      {values.map((value, index) => (
        <span key={index} className="inline-flex items-center rounded bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-800 dark:bg-gray-800 dark:text-gray-200">
          {formatValue(value)}
        </span>
      ))}
    </div>
  )
}

function Subheading({ children }: { children: ReactNode }) {
  return <h3 className="mb-3 text-sm font-semibold text-gray-900 dark:text-white">{children}</h3>
}

function TenantContextSummary({ context }: { context: AnyRecord }) {
  const services = context.Services && typeof context.Services === "object"
    ? Object.entries(context.Services).filter(([, connected]) => connected).map(([name]) => name)
    : []
  const licenses = context.Licenses || {}
  const servicePlans = asArray(licenses.ServicePlanNames)
  return (
    <dl className="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <Field label="Tenant type">{context.TenantType || "Unknown"}</Field>
      <Field label="Cloud">{context.Cloud || "Unknown"}</Field>
      <Field label="Platform">{context.Platform || "Unknown"}</Field>
      {context.Account && <Field label="Account">{String(context.Account)}</Field>}
      {context.AuthType && <Field label="Auth type">{String(context.AuthType)}</Field>}
      <Field label="Licenses">
        {licenses.State || "Unknown"}
        {servicePlans.length > 0 && <span className="text-gray-500 dark:text-gray-400"> ({servicePlans.length} service plans)</span>}
      </Field>
      <Field label="Connected services" wide>
        <Chips values={services} empty="None connected" />
      </Field>
    </dl>
  )
}

// Run configuration recorded by result schema 2.1 (Maester 3.0): selection, metadata, tenant context
// and partitions. Returns null for 2.x results, which carry none of these fields.
export default function RunConfiguration({ results }: { results: AnyRecord }) {
  if (!hasRunConfiguration(results)) return null

  const selection: AnyRecord = results.Selection || {}
  const unknownIds = asArray<string>(selection.UnknownIds).filter(Boolean)
  const superseded = asArray<AnyRecord>(selection.Superseded).filter(Boolean)
  const metadata = results.RunMetadata && typeof results.RunMetadata === "object" ? Object.entries(results.RunMetadata) : []
  const partitions = asArray<AnyRecord>(results.Partitions).filter(Boolean)
  const catalogVersion = formatVersion(results.CatalogVersion)
  const builtIn = selection.BuiltIn

  return (
    <section>
      <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
        Run Configuration
      </h2>
      <div className="space-y-6 rounded-md border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900">
        {selection.DryRun && (
          <div className="rounded-md bg-amber-500/10 px-4 py-3 text-sm text-amber-700 ring-1 ring-inset ring-amber-500/20 dark:text-amber-400">
            <span className="font-semibold">Dry run.</span> No tests were executed; the report lists the tests the run would have included.
          </div>
        )}

        <dl className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <Field label="Result schema">{results.SchemaVersion || "2.0"}</Field>
          <Field label="Catalog version">{catalogVersion || "N/A"}</Field>
          <Field label="Built-in tests">
            {builtIn === "None" ? "Not included" : builtIn === "All" ? "Included" : builtIn ? String(builtIn) : "N/A"}
          </Field>
          {"IncludeTag" in selection && <Field label="Include tags"><Chips values={asArray(selection.IncludeTag).filter(Boolean)} /></Field>}
          {"ExcludeTag" in selection && <Field label="Exclude tags" wide><Chips values={asArray(selection.ExcludeTag).filter(Boolean)} /></Field>}
          <Field label="Unknown IDs" wide>
            <Chips values={unknownIds} />
          </Field>
        </dl>

        <div>
          <Subheading>Superseded stale copies ({superseded.length})</Subheading>
          {superseded.length > 0 ? (
            <>
              <p className="mb-2 text-sm text-gray-500 dark:text-gray-400">
                These local copies of older built-in tests were not run and have no row in the results. Run Update-MaesterTests to remove them.
              </p>
              <div className="overflow-x-auto">
                <table className="min-w-full text-left text-sm">
                  <thead className="text-xs text-gray-500 dark:text-gray-400">
                    <tr>
                      <th className="py-1 pr-4 font-medium">ID</th>
                      <th className="py-1 pr-4 font-medium">File</th>
                      <th className="py-1 font-medium">Matched by</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                    {superseded.map((item, index) => (
                      <tr key={index}>
                        <td className="whitespace-nowrap py-1 pr-4 font-mono text-gray-900 dark:text-gray-100">{item.Id}</td>
                        <td className="break-all py-1 pr-4 font-mono text-xs text-gray-700 dark:text-gray-300">{item.File}</td>
                        <td className="whitespace-nowrap py-1 text-gray-500 dark:text-gray-400">{item.MatchedBy}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          ) : (
            <p className="text-sm text-gray-400">None</p>
          )}
        </div>

        {metadata.length > 0 && (
          <div>
            <Subheading>Run metadata</Subheading>
            <dl className="grid grid-cols-1 gap-4 sm:grid-cols-3">
              {metadata.map(([key, value]) => (
                <Field key={key} label={key}>
                  <span className="break-all">{formatValue(value)}</span>
                </Field>
              ))}
            </dl>
          </div>
        )}

        {results.TenantContext && typeof results.TenantContext === "object" && (
          <div>
            <Subheading>Tenant context</Subheading>
            <TenantContextSummary context={results.TenantContext} />
          </div>
        )}

        {partitions.length > 0 && (
          <div>
            <Subheading>Partitions ({partitions.length})</Subheading>
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="text-xs text-gray-500 dark:text-gray-400">
                  <tr>
                    <th className="py-1 pr-4 font-medium">#</th>
                    <th className="py-1 pr-4 font-medium">Tenant</th>
                    <th className="py-1 pr-4 font-medium">Executed</th>
                    <th className="py-1 pr-4 font-medium">Duration</th>
                    <th className="py-1 pr-4 font-medium">Result</th>
                    <th className="py-1 pr-4 font-medium">Tests</th>
                    <th className="py-1 font-medium">Command</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                  {partitions.map((partition, index) => (
                    <tr key={index} className="align-top">
                      <td className="py-1 pr-4 text-gray-500 dark:text-gray-400">{index + 1}</td>
                      <td className="whitespace-nowrap py-1 pr-4 font-mono text-xs text-gray-900 dark:text-gray-100">
                        {partition.TenantId || partition.TenantContext?.TenantId || "N/A"}
                      </td>
                      <td className="whitespace-nowrap py-1 pr-4 text-gray-700 dark:text-gray-300">
                        {partition.ExecutedAt ? new Date(partition.ExecutedAt).toLocaleString() : "N/A"}
                      </td>
                      <td className="whitespace-nowrap py-1 pr-4 text-gray-700 dark:text-gray-300">{partition.TotalDuration || "N/A"}</td>
                      <td className="whitespace-nowrap py-1 pr-4 text-gray-700 dark:text-gray-300">{partition.Result || "N/A"}</td>
                      <td className="whitespace-nowrap py-1 pr-4 text-gray-700 dark:text-gray-300">{partition.TotalCount ?? "N/A"}</td>
                      <td className="py-1">
                        {partition.InvokeCommand
                          ? <code className="break-words font-mono text-xs text-gray-700 dark:text-gray-300">{partition.InvokeCommand}</code>
                          : <span className="text-gray-400">N/A</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </section>
  )
}
