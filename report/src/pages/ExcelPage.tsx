import { useState } from "react"
import { Button } from "@/components/Button"
import { Dialog, DialogPanel } from "@tremor/react"
import { RiClipboardLine, RiCheckLine } from "@remixicon/react"
import { testResults } from "@/lib/testResults"

export default function ExcelPage() {
  const [isDialogOpen, setIsDialogOpen] = useState(false)

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
    setIsDialogOpen(true)
  }

  return (
    <div>
      {/* Copy Success Dialog */}
      <Dialog open={isDialogOpen} onClose={() => setIsDialogOpen(false)} static={true}>
        <DialogPanel className="max-w-md">
          <div className="flex flex-col items-center text-center">
            <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-green-100 dark:bg-green-900">
              <RiCheckLine className="h-6 w-6 text-green-600 dark:text-green-400" />
            </div>
            <h3 className="mb-2 text-lg font-semibold text-gray-900 dark:text-white">
              Copied to Clipboard!
            </h3>
            <p className="mb-4 text-sm text-gray-600 dark:text-gray-400">
              The test results have been copied to your clipboard.
            </p>
            <div className="mb-6 rounded-lg bg-gray-50 p-4 text-left dark:bg-gray-800">
              <p className="mb-2 text-sm font-medium text-gray-900 dark:text-white">
                To paste into Excel:
              </p>
              <ol className="list-decimal space-y-1 pl-4 text-sm text-gray-600 dark:text-gray-400">
                <li>Open Microsoft Excel</li>
                <li>Select the cell where you want to paste (e.g., A1)</li>
                <li>Press <kbd className="rounded bg-gray-200 px-1.5 py-0.5 font-mono text-xs dark:bg-gray-700">Ctrl+V</kbd> (Windows) or <kbd className="rounded bg-gray-200 px-1.5 py-0.5 font-mono text-xs dark:bg-gray-700">⌘+V</kbd> (Mac)</li>
              </ol>
            </div>
            <Button variant="primary" onClick={() => setIsDialogOpen(false)}>
              Done
            </Button>
          </div>
        </DialogPanel>
      </Dialog>

      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-gray-900 dark:text-white">
          Excel
        </h1>
        <Button variant="primary" onClick={copyToClipboard}>
          <RiClipboardLine className="mr-2 h-4 w-4" />
          Copy to Excel
        </Button>
      </div>

      <div className="overflow-x-auto rounded-md border border-gray-200 dark:border-gray-700">
        <table className="min-w-full border-collapse text-left text-sm text-gray-600 dark:text-gray-300">
          <thead className="bg-gray-50 text-xs uppercase text-gray-700 dark:bg-gray-800 dark:text-gray-300">
            <tr>
              <th className="border-b border-gray-200 p-2 dark:border-gray-700">ID</th>
              <th className="border-b border-gray-200 p-2 dark:border-gray-700">Title</th>
              <th className="border-b border-gray-200 p-2 dark:border-gray-700">Severity</th>
              <th className="border-b border-gray-200 p-2 dark:border-gray-700">Status</th>
              <th className="border-b border-gray-200 p-2 dark:border-gray-700">Category</th>
              <th className="border-b border-gray-200 p-2 dark:border-gray-700">Description</th>
              <th className="border-b border-gray-200 p-2 dark:border-gray-700">Result</th>
              <th className="border-b border-gray-200 p-2 dark:border-gray-700">Tags</th>
              <th className="border-b border-gray-200 p-2 dark:border-gray-700">Notes</th>
            </tr>
          </thead>
          <tbody>
            {testResults.Tests.map((test, index) => (
              <tr
                key={index}
                className="border-b border-gray-200 bg-white hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:hover:bg-gray-800"
              >
                <td className="max-w-40 truncate p-2 font-medium text-gray-900 dark:text-white">
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
