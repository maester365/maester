"use client"

import { Button } from "@/components/Button"
import { RiClipboardLine } from "@remixicon/react"
import { testResults } from "@/lib/testResults"

export default function ExcelPage() {
  const copyToClipboard = () => {
    const headers = [
      "ID",
      "Title",
      "Severity",
      "Status",
      "Category",
      "Description",
      "Result",
      "Tags",
      "Notes",
    ]
    const rows = testResults.Tests.map((test) => {
      return [
        test.Id,
        test.Title,
        test.Severity,
        test.Result,
        test.Block,
        test.ResultDetail?.TestDescription,
        test.ResultDetail?.TestResult,
        test.Tag?.join(", "),
        test.ResultDetail?.SkippedReason,
      ]
        .map((field) => {
          if (field == null) return ""
          let str = String(field)
          str = str.replace(/\t/g, " ").replace(/(\r\n|\n|\r)/g, " ")
          return str
        })
        .join("\t")
    })

    const tsv = [headers.join("\t"), ...rows].join("\n")
    navigator.clipboard.writeText(tsv)
  }

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-gray-900">
          Excel
        </h1>
        <Button variant="primary" onClick={copyToClipboard}>
          <RiClipboardLine className="mr-2 h-4 w-4" />
          Copy to Excel
        </Button>
      </div>

      <div className="overflow-x-auto rounded-md border border-gray-200">
        <table className="min-w-full border-collapse text-left text-sm text-gray-600">
          <thead className="bg-gray-50 text-xs uppercase text-gray-700">
            <tr>
              <th className="border-b border-gray-200 p-2">ID</th>
              <th className="border-b border-gray-200 p-2">Title</th>
              <th className="border-b border-gray-200 p-2">Severity</th>
              <th className="border-b border-gray-200 p-2">Status</th>
              <th className="border-b border-gray-200 p-2">Category</th>
              <th className="border-b border-gray-200 p-2">Description</th>
              <th className="border-b border-gray-200 p-2">Result</th>
              <th className="border-b border-gray-200 p-2">Tags</th>
              <th className="border-b border-gray-200 p-2">Notes</th>
            </tr>
          </thead>
          <tbody>
            {testResults.Tests.map((test, index) => (
              <tr
                key={index}
                className="border-b border-gray-200 bg-white hover:bg-gray-50"
              >
                <td className="max-w-40 truncate p-2 font-medium text-gray-900">
                  {test.Id}
                </td>
                <td className="p-2">{test.Title}</td>
                <td className="p-2">{test.Severity}</td>
                <td className="max-w-xs truncate p-2">{test.Result}</td>
                <td className="max-w-20 truncate p-2">{test.Block}</td>
                <td
                  className="max-w-xs truncate p-2"
                  title={test.ResultDetail?.TestDescription}
                >
                  {test.ResultDetail?.TestDescription}
                </td>
                <td className="max-w-xs truncate p-2">
                  {test.ResultDetail?.TestResult}
                </td>
                <td className="p-2">{test.Tag?.join(", ")}</td>
                <td className="max-w-xs truncate p-2">
                  {test.ResultDetail?.SkippedReason}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
