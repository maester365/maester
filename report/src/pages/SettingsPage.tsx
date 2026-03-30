import { useTenant } from "@/context/TenantContext"
import { Divider } from "@/components/Divider"

export default function SettingsPage() {
  const { selectedTenant: testResults } = useTenant()

  return (
    <div className="max-w-3xl">
      <h1 className="mb-6 text-2xl font-semibold text-gray-900 dark:text-gray-100">
        Settings
      </h1>

      <div className="space-y-8">
        {/* Tenant Information */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
            Tenant Information
          </h2>
          <div className="rounded-md border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900">
            <dl className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Tenant Name
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {testResults.TenantName}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Tenant ID
                </dt>
                <dd className="mt-1 font-mono text-sm text-gray-900 dark:text-gray-100">
                  {testResults.TenantId}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Test Date
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {new Date(testResults.ExecutedAt).toLocaleString()}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Report Version
                </dt>
                <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                  {testResults.CurrentVersion}
                </dd>
              </div>
            </dl>
          </div>
        </section>

        <Divider />

        {/* Test Summary */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
            Test Summary
          </h2>
          <div className="rounded-md border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900">
            <dl className="grid grid-cols-2 gap-4 sm:grid-cols-5">
              <div className="text-center">
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Total
                </dt>
                <dd className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                  {testResults.TotalCount}
                </dd>
              </div>
              <div className="text-center">
                <dt className="text-sm font-medium text-emerald-600 dark:text-emerald-400">
                  Passed
                </dt>
                <dd className="mt-1 text-2xl font-semibold text-emerald-600 dark:text-emerald-400">
                  {testResults.PassedCount}
                </dd>
              </div>
              <div className="text-center">
                <dt className="text-sm font-medium text-red-600 dark:text-red-400">
                  Failed
                </dt>
                <dd className="mt-1 text-2xl font-semibold text-red-600 dark:text-red-400">
                  {testResults.FailedCount}
                </dd>
              </div>
              <div className="text-center">
                <dt className="text-sm font-medium text-purple-600 dark:text-purple-400">
                  Investigate
                </dt>
                <dd className="mt-1 text-2xl font-semibold text-purple-600 dark:text-purple-400">
                  {testResults.InvestigateCount || 0}
                </dd>
              </div>
              <div className="text-center">
                <dt className="text-sm font-medium text-amber-600 dark:text-amber-400">
                  Skipped
                </dt>
                <dd className="mt-1 text-2xl font-semibold text-amber-600 dark:text-amber-400">
                  {testResults.SkippedCount}
                </dd>
              </div>
            </dl>
          </div>
        </section>

        <Divider />

        {/* About */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
            About Maester
          </h2>
          <div className="rounded-md border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900">
            <p className="text-gray-600 dark:text-gray-400">
              Maester is a PowerShell-based test automation framework for
              Microsoft 365 and Azure. It runs security configuration checks and
              generates detailed reports to help organizations maintain
              compliance and best practices.
            </p>
            <div className="mt-4">
              <a
                href="https://maester.dev"
                target="_blank"
                rel="noopener noreferrer"
                className="text-orange-600 hover:text-orange-700 dark:text-orange-400 dark:hover:text-orange-300"
              >
                Learn more at maester.dev →
              </a>
            </div>
          </div>
        </section>
      </div>
    </div>
  )
}
