import { useState, useEffect } from "react"
import { testResults } from "@/lib/testResults"
import { Button } from "@/components/Button"
import { RiPrinterLine } from "@remixicon/react"
import StatusLabel from "@/components/StatusLabel"
import SeverityBadge from "@/components/SeverityBadge"
import ResultInfo from "@/components/ResultInfo"
import maesterLogo from "@/assets/maester.png"

export default function PrintPage() {
  const [isPrinting, setIsPrinting] = useState(false)
  const tenantName = testResults.TenantName || testResults.TenantId || "Tenant"
  const testDateLocal = new Date(testResults.ExecutedAt).toLocaleString(
    undefined,
    {
      dateStyle: "medium",
      timeStyle: "short",
    }
  )

  const handlePrint = () => {
    setIsPrinting(true)
    setTimeout(() => {
      window.print()
      setIsPrinting(false)
    }, 100)
  }

  // Print stylesheet
  useEffect(() => {
    const printStyles = document.createElement("style")
    printStyles.id = "print-styles"
    printStyles.innerHTML = `
      @media print {
        body * {
          visibility: hidden;
        }
        .print-content, .print-content * {
          visibility: visible;
        }
        .print-content {
          position: absolute;
          left: 0;
          top: 0;
          width: 100%;
        }
        .no-print {
          display: none !important;
        }
        table {
          font-size: 10px;
        }
        .detail-section {
          page-break-inside: avoid;
        }
      }
    `
    document.head.appendChild(printStyles)
    return () => {
      const styles = document.getElementById("print-styles")
      if (styles) styles.remove()
    }
  }, [])

  return (
    <div>
      <div className="no-print mb-6 flex items-center justify-end">
        <Button variant="primary" onClick={handlePrint} disabled={isPrinting}>
          <RiPrinterLine className="mr-2 h-4 w-4" />
          {isPrinting ? "Preparing..." : "Print Report"}
        </Button>
      </div>

      <div className="print-content">
        {/* Report Header */}
        <div className="mb-6">
          <div className="mb-4 flex items-center gap-3">
            <img
              src={maesterLogo}
              alt="Maester Logo"
              className="h-10 w-10"
            />
            <h1 className="text-2xl font-semibold tracking-tight text-gray-900 dark:text-gray-100">
              Maester Test Results
            </h1>
          </div>
          <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
            {tenantName} • {testDateLocal}
          </p>
        </div>

        {/* Summary */}
        <div className="mb-8 grid grid-cols-4 gap-4">
          <div className="rounded-md border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <div className="text-2xl font-semibold text-gray-900 dark:text-white">
              {testResults.TotalCount}
            </div>
            <div className="text-sm text-gray-500 dark:text-gray-400">
              Total Tests
            </div>
          </div>
          <div className="rounded-md border border-emerald-200 bg-emerald-50 p-4 dark:border-emerald-800 dark:bg-emerald-950">
            <div className="text-2xl font-semibold text-emerald-700 dark:text-emerald-400">
              {testResults.PassedCount}
            </div>
            <div className="text-sm text-emerald-600 dark:text-emerald-500">
              Passed
            </div>
          </div>
          <div className="rounded-md border border-red-200 bg-red-50 p-4 dark:border-red-800 dark:bg-red-950">
            <div className="text-2xl font-semibold text-red-700 dark:text-red-400">
              {testResults.FailedCount}
            </div>
            <div className="text-sm text-red-600 dark:text-red-500">Failed</div>
          </div>
          <div className="rounded-md border border-purple-200 bg-purple-50 p-4 dark:border-purple-800 dark:bg-purple-950">
            <div className="text-2xl font-semibold text-purple-700 dark:text-purple-400">
              {testResults.InvestigateCount || 0}
            </div>
            <div className="text-sm text-purple-600 dark:text-purple-500">
              Investigate
            </div>
          </div>
          <div className="rounded-md border border-amber-200 bg-amber-50 p-4 dark:border-amber-800 dark:bg-amber-950">
            <div className="text-2xl font-semibold text-amber-700 dark:text-amber-400">
              {testResults.SkippedCount}
            </div>
            <div className="text-sm text-amber-600 dark:text-amber-500">
              Skipped
            </div>
          </div>
        </div>

        {/* Test Results Summary Table */}
        <div className="mb-8">
          <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-white">
            Summary
          </h2>
          <div className="overflow-x-auto rounded-md border border-gray-200 dark:border-gray-700">
            <table className="min-w-full border-collapse text-left text-sm dark:text-gray-300">
              <thead className="bg-gray-50 text-gray-700 dark:bg-gray-800 dark:text-gray-300">
                <tr>
                  <th className="border-b border-gray-200 p-2 dark:border-gray-700">
                    ID
                  </th>
                  <th className="border-b border-gray-200 p-2 dark:border-gray-700">
                    Title
                  </th>
                  <th className="border-b border-gray-200 p-2 text-center dark:border-gray-700">
                    Severity
                  </th>
                  <th className="border-b border-gray-200 p-2 text-center dark:border-gray-700">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody>
                {testResults.Tests.map((test, index) => (
                  <tr
                    key={index}
                    className="border-b border-gray-200 bg-white hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:hover:bg-gray-800"
                  >
                    <td className="p-2 font-mono text-xs text-gray-900 dark:text-gray-300">
                      {test.Id}
                    </td>
                    <td className="p-2 dark:text-gray-300">
                      <button
                        onClick={() => {
                          const element = document.getElementById(`detail-${test.Id}`)
                          if (element) {
                            element.scrollIntoView({ behavior: "smooth" })
                          }
                        }}
                        className="text-left text-blue-600 hover:text-blue-800 hover:underline dark:text-blue-400 dark:hover:text-blue-300"
                      >
                        {test.Title || test.Name}
                      </button>
                    </td>
                    <td className="p-2 text-center">
                      <SeverityBadge Severity={test.Severity} />
                    </td>
                    <td className="p-2 text-center">
                      <StatusLabel Result={test.Result} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Test Details Section */}
        <div>
          <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-white">
            Test Details
          </h2>
          <div className="space-y-6">
            {testResults.Tests.map((test, index) => (
              <div
                key={index}
                id={`detail-${test.Id}`}
                className="detail-section rounded-md border border-gray-200 p-4 dark:border-gray-700"
              >
                <ResultInfo Item={test} isPrintView={true} />
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
