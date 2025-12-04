import { testResults } from "@/lib/testResults"
import { Divider } from "@/components/Divider"
import { useState } from "react"
import { ChevronDown, ChevronRight } from "lucide-react"

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function ConfigSection({ title, config }: { title: string; config: any }) {
  const [isExpanded, setIsExpanded] = useState(false)

  if (!config) return null

  return (
    <div className="border-b border-gray-200 last:border-b-0 dark:border-gray-700">
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="flex w-full items-center gap-2 px-4 py-3 text-left hover:bg-gray-50 dark:hover:bg-gray-800"
      >
        {isExpanded ? (
          <ChevronDown className="h-4 w-4 text-gray-500" />
        ) : (
          <ChevronRight className="h-4 w-4 text-gray-500" />
        )}
        <span className="font-medium text-gray-900 dark:text-gray-100">{title}</span>
      </button>
      {isExpanded && (
        <div className="bg-gray-50 px-4 py-3 dark:bg-gray-800/50">
          <dl className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            {Object.entries(config).map(([key, value]) => (
              <div key={key} className="overflow-hidden">
                <dt className="text-xs font-medium text-gray-500 dark:text-gray-400">
                  {key}
                </dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {Array.isArray(value) ? (
                    value.length > 0 ? (
                      <div className="flex flex-wrap gap-1">
                        {value.map((item, idx) => (
                          <span
                            key={idx}
                            className="inline-flex items-center rounded bg-gray-200 px-2 py-0.5 text-xs font-medium text-gray-800 dark:bg-gray-700 dark:text-gray-200"
                          >
                            {String(item)}
                          </span>
                        ))}
                      </div>
                    ) : (
                      <span className="text-gray-400">(empty)</span>
                    )
                  ) : typeof value === "boolean" ? (
                    <span className={value ? "text-green-600 dark:text-green-400" : "text-gray-400"}>
                      {value ? "True" : "False"}
                    </span>
                  ) : (
                    String(value) || <span className="text-gray-400">(not set)</span>
                  )}
                </dd>
              </div>
            ))}
          </dl>
        </div>
      )}
    </div>
  )
}

export default function SystemPage() {
  const systemInfo = testResults.SystemInfo || {}
  const powerShellInfo = testResults.PowerShellInfo || {}
  const loadedModules = testResults.LoadedModules || []
  const mgContext = testResults.MgContext || {}
  const invokeCommand = testResults.InvokeCommand || "Not available"
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const pesterConfig = (testResults as any).PesterConfig || null

  return (
    <div className="max-w-4xl">
      <h1 className="mb-6 text-2xl font-semibold text-gray-900 dark:text-white">
        System Information
      </h1>

      <div className="space-y-8">
        {/* Invoke Command */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            Command Executed
          </h2>
          <div className="rounded-md border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900">
            <code className="block whitespace-pre-wrap break-all rounded bg-gray-100 p-3 font-mono text-sm text-gray-800 dark:bg-gray-800 dark:text-gray-200">
              {invokeCommand}
            </code>
          </div>
        </section>

        <Divider />

        {/* Graph Connection */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            Graph Connection
          </h2>
          <div className="rounded-md border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900">
            {mgContext && Object.keys(mgContext).length > 0 ? (
              <dl className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Account
                  </dt>
                  <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                    {mgContext.Account || "N/A"}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Tenant ID
                  </dt>
                  <dd className="mt-1 font-mono text-sm text-gray-900 dark:text-gray-100">
                    {mgContext.TenantId || "N/A"}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    App Name
                  </dt>
                  <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                    {mgContext.AppName || "N/A"}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Client ID
                  </dt>
                  <dd className="mt-1 font-mono text-sm text-gray-900 dark:text-gray-100">
                    {mgContext.ClientId || "N/A"}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Auth Type
                  </dt>
                  <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                    {mgContext.AuthType || "N/A"}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Token Credential Type
                  </dt>
                  <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                    {mgContext.TokenCredentialType || "N/A"}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Context Scope
                  </dt>
                  <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                    {mgContext.ContextScope || "N/A"}
                  </dd>
                </div>
                {mgContext.ManagedIdentityId && (
                  <div>
                    <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                      Managed Identity ID
                    </dt>
                    <dd className="mt-1 font-mono text-sm text-gray-900 dark:text-gray-100">
                      {mgContext.ManagedIdentityId}
                    </dd>
                  </div>
                )}
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Environment
                  </dt>
                  <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                    {mgContext.Environment || "N/A"}
                  </dd>
                </div>
                <div className="sm:col-span-2">
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Scopes
                  </dt>
                  <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                    {mgContext.Scopes && mgContext.Scopes.length > 0 ? (
                      <div className="flex flex-wrap gap-1">
                        {mgContext.Scopes.map((scope: string, index: number) => (
                          <span
                            key={index}
                            className="inline-flex items-center rounded bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-800 dark:bg-gray-800 dark:text-gray-200"
                          >
                            {scope}
                          </span>
                        ))}
                      </div>
                    ) : (
                      "N/A"
                    )}
                  </dd>
                </div>
              </dl>
            ) : (
              <p className="text-gray-500 dark:text-gray-400">
                Graph connection information is not available.
              </p>
            )}
          </div>
        </section>

        <Divider />

        {/* System Information */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            System
          </h2>
          <div className="rounded-md border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900">
            <dl className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Machine Name
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {systemInfo.MachineName || "N/A"}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Operating System
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {systemInfo.OSDescription || "N/A"}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Platform
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {systemInfo.OSPlatform || "N/A"}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Processor Count
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {systemInfo.ProcessorCount || "N/A"}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  User Name
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {systemInfo.UserName || "N/A"}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  User Domain
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {systemInfo.UserDomain || "N/A"}
                </dd>
              </div>
            </dl>
          </div>
        </section>

        <Divider />

        {/* PowerShell Information */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            PowerShell
          </h2>
          <div className="rounded-md border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900">
            <dl className="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Version
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {powerShellInfo.Version || "N/A"}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Edition
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {powerShellInfo.Edition || "N/A"}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Platform
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {powerShellInfo.Platform || "N/A"}
                </dd>
              </div>
            </dl>
          </div>
        </section>

        <Divider />

        {/* Pester Configuration */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            Pester Configuration
          </h2>
          <div className="rounded-md border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
            {pesterConfig ? (
              <div className="divide-y divide-gray-200 dark:divide-gray-700">
                <ConfigSection title="Run" config={pesterConfig.Run} />
                <ConfigSection title="Filter" config={pesterConfig.Filter} />
                <ConfigSection title="Output" config={pesterConfig.Output} />
                <ConfigSection title="TestResult" config={pesterConfig.TestResult} />
                <ConfigSection title="CodeCoverage" config={pesterConfig.CodeCoverage} />
                <ConfigSection title="Should" config={pesterConfig.Should} />
                <ConfigSection title="Debug" config={pesterConfig.Debug} />
              </div>
            ) : (
              <p className="p-6 text-gray-500 dark:text-gray-400">
                Pester configuration information is not available.
              </p>
            )}
          </div>
        </section>

        <Divider />

        {/* Loaded Modules */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
            Loaded PowerShell Modules
          </h2>
          <div className="rounded-md border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
            {loadedModules && loadedModules.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                  <thead className="bg-gray-50 dark:bg-gray-800">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                        Module Name
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                        Version
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-900">
                    {loadedModules.map((module: { Name: string; Version: string }, index: number) => (
                      <tr key={index}>
                        <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-gray-900 dark:text-gray-100">
                          {module.Name}
                        </td>
                        <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                          {module.Version}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="p-6 text-gray-500 dark:text-gray-400">
                No module information available.
              </p>
            )}
          </div>
        </section>
      </div>
    </div>
  )
}
