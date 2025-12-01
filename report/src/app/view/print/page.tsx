"use client"

import { useState, useEffect } from "react"
import { testResults } from "@/lib/testResults"
import { Button } from "@/components/Button"
import { RiPrinterLine } from "@remixicon/react"

export default function PrintPage() {
  const [isPrinting, setIsPrinting] = useState(false)

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
      <div className="no-print mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-gray-900">
          Print Report
        </h1>
        <Button variant="primary" onClick={handlePrint} disabled={isPrinting}>
          <RiPrinterLine className="mr-2 h-4 w-4" />
          {isPrinting ? "Preparing..." : "Print Report"}
        </Button>
      </div>

      <div className="print-content">
        {/* Report Header */}
        <div className="mb-8">
          <h1 className="text-2xl font-semibold text-gray-900">
            Maester Test Results
          </h1>
          <p className="text-sm text-gray-500">
            Tenant: {testResults.TenantName} ({testResults.TenantId})
          </p>
          <p className="text-sm text-gray-500">
            Generated: {new Date(testResults.ExecutedAt).toLocaleString()}
          </p>
        </div>

        {/* Summary */}
        <div className="mb-8 grid grid-cols-4 gap-4">
          <div className="rounded-md border border-gray-200 bg-white p-4">
            <div className="text-2xl font-semibold text-gray-900">
              {testResults.TotalCount}
            </div>
            <div className="text-sm text-gray-500">
              Total Tests
            </div>
          </div>
          <div className="rounded-md border border-emerald-200 bg-emerald-50 p-4">
            <div className="text-2xl font-semibold text-emerald-700">
              {testResults.PassedCount}
            </div>
            <div className="text-sm text-emerald-600">
              Passed
            </div>
          </div>
          <div className="rounded-md border border-red-200 bg-red-50 p-4">
            <div className="text-2xl font-semibold text-red-700">
              {testResults.FailedCount}
            </div>
            <div className="text-sm text-red-600">Failed</div>
          </div>
          <div className="rounded-md border border-amber-200 bg-amber-50 p-4">
            <div className="text-2xl font-semibold text-amber-700">
              {testResults.SkippedCount}
            </div>
            <div className="text-sm text-amber-600">
              Skipped
            </div>
          </div>
        </div>

        {/* Test Results Table */}
        <div className="overflow-x-auto rounded-md border border-gray-200">
          <table className="min-w-full border-collapse text-left text-xs">
            <thead className="bg-gray-50 text-gray-700">
              <tr>
                <th className="border-b border-gray-200 p-2">
                  ID
                </th>
                <th className="border-b border-gray-200 p-2">
                  Title
                </th>
                <th className="border-b border-gray-200 p-2">
                  Status
                </th>
                <th className="border-b border-gray-200 p-2">
                  Severity
                </th>
                <th className="border-b border-gray-200 p-2">
                  Description
                </th>
              </tr>
            </thead>
            <tbody>
              {testResults.Tests.map((test, index) => (
                <tr
                  key={index}
                  className={`${
                    test.Result === "Passed"
                      ? "bg-emerald-50"
                      : test.Result === "Failed"
                        ? "bg-red-50"
                        : "bg-white"
                  }`}
                >
                  <td className="border-b border-gray-200 p-2 font-mono text-xs">
                    {test.Id}
                  </td>
                  <td className="border-b border-gray-200 p-2">
                    {test.Title}
                  </td>
                  <td className="border-b border-gray-200 p-2">
                    <span
                      className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
                        test.Result === "Passed"
                          ? "bg-emerald-100 text-emerald-800"
                          : test.Result === "Failed"
                            ? "bg-red-100 text-red-800"
                            : "bg-amber-100 text-amber-800"
                      }`}
                    >
                      {test.Result}
                    </span>
                  </td>
                  <td className="border-b border-gray-200 p-2">
                    {test.Severity}
                  </td>
                  <td className="border-b border-gray-200 p-2">
                    {test.ResultDetail?.TestDescription}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
