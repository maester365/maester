import { useState, useEffect } from "react"
import { Markdown } from "@/components/Markdown"
import { Button } from "@/components/Button"
import { Dialog, DialogPanel } from "@/components/ui/report"
import { RiClipboardLine, RiEyeLine, RiCodeLine, RiCheckLine } from "@remixicon/react"
import { useTenant } from "@/context/TenantContext"

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function generateMarkdown(results: any) {
  const testDateLocal = new Date(results.ExecutedAt).toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  })
  const tenantName = results.TenantName
    ? `${results.TenantName} (${results.TenantId})`
    : `Tenant ID: ${results.TenantId}`

  let md = `# Maester Test Results\n\n`
  md += `**Tenant:** ${tenantName}  \n`
  md += `**Date:** ${testDateLocal}\n\n`

  md += `## Test Summary\n\n`
  md += `| Total | Passed | Failed | Investigate | Skipped | Not Run | Error |\n`
  md += `| :---: | :---: | :---: | :---: | :---: | :---: | :---: |\n`
  md += `| ${results.TotalCount} | ${results.PassedCount} | ${results.FailedCount} | ${results.InvestigateCount || 0} | ${results.SkippedCount} | ${results.NotRunCount || 0} | ${results.ErrorCount || 0} |\n\n`

  md += `## Test Results\n\n`
  md += `| Name | Severity | Result |\n`
  md += `| :--- | :---: | :---: |\n`
  results.Tests.forEach((test: any) => {
    const safeName = test.Name.replace(/\\/g, "\\\\").replace(/\|/g, "\\|")
    md += `| ${safeName} | ${test.Severity} | ${test.Result} |\n`
  })
  md += `\n`

  md += `## Test Details\n\n`

  results.Tests.forEach((test: any) => {
    const icon =
      test.Result === "Passed"
        ? "✅"
        : test.Result === "Failed"
          ? "❌"
          : test.Result === "Skipped"
            ? "⏭️"
            : test.Result === "Investigate"
              ? "🔍"
              : "⚠️"
    md += `### ${icon} ${test.Name}\n\n`
    md += `**Result:** ${test.Result}  \n`
    md += `**Severity:** ${test.Severity}  \n`
    if (test.HelpUrl) {
      md += `**Help:** [Link](${test.HelpUrl})\n`
    }
    md += `\n`

    if (test.ResultDetail) {
      if (test.ResultDetail.TestDescription) {
        md += `${test.ResultDetail.TestDescription}\n\n`
      }
      if (test.ResultDetail.TestResult) {
        md += `**Output:**\n\n${test.ResultDetail.TestResult}\n\n`
      }
    }
    md += `---\n\n`
  })

  return md
}

export default function MarkdownPage() {
  const { selectedTenant: testResults } = useTenant()
  const [markdown, setMarkdown] = useState(generateMarkdown(testResults))
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [activeTab, setActiveTab] = useState<"markdown" | "preview">("preview")

  // Regenerate markdown when tenant changes
  useEffect(() => {
    setMarkdown(generateMarkdown(testResults))
  }, [testResults])

  const copyToClipboard = () => {
    navigator.clipboard.writeText(markdown)
    setIsDialogOpen(true)
  }

  return (
    <div className="mx-auto max-w-5xl">
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
            <p className="mb-6 text-sm text-gray-600 dark:text-gray-400">
              The markdown format of the test results has been copied to your clipboard. You can now paste it into any markdown editor or document.
            </p>
            <Button variant="primary" onClick={() => setIsDialogOpen(false)}>
              Done
            </Button>
          </div>
        </DialogPanel>
      </Dialog>

      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-gray-900 dark:text-white">
          Markdown
        </h1>
        <Button variant="primary" onClick={copyToClipboard}>
          <RiClipboardLine className="mr-2 h-4 w-4" />
          Copy Markdown
        </Button>
      </div>

      <div className="mt-8">
        <div className="flex h-[38px] gap-4 border-b border-gray-200 dark:border-zinc-800" role="tablist">
          <button type="button" role="tab" aria-selected={activeTab === "markdown"} onClick={() => setActiveTab("markdown")} className={`flex h-[38px] gap-2 px-2 py-2 text-sm transition duration-100 ${activeTab === "markdown" ? "border-b-2 border-blue-500 text-blue-500" : "text-gray-500 hover:border-b-2 hover:border-gray-500 hover:text-gray-700 dark:text-zinc-500 dark:hover:border-zinc-200 dark:hover:text-zinc-200"}`}><RiCodeLine className="size-5" />Markdown</button>
          <button type="button" role="tab" aria-selected={activeTab === "preview"} onClick={() => setActiveTab("preview")} className={`flex h-[38px] gap-2 px-2 py-2 text-sm transition duration-100 ${activeTab === "preview" ? "border-b-2 border-blue-500 text-blue-500" : "text-gray-500 hover:border-b-2 hover:border-gray-500 hover:text-gray-700 dark:text-zinc-500 dark:hover:border-zinc-200 dark:hover:text-zinc-200"}`}><RiEyeLine className="size-5" />Preview</button>
        </div>
          {activeTab === "markdown" ? (
            <div className="mt-4">
              <textarea
                className="h-[80vh] w-full rounded-md border border-gray-200 bg-white p-4 font-mono text-sm text-gray-900 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
                value={markdown}
                onChange={(e) => setMarkdown(e.target.value)}
              />
            </div>
          ) : (
            <Markdown className="prose mt-4 max-w-none rounded-md border border-gray-200 bg-white p-4 dark:prose-invert dark:border-gray-700 dark:bg-gray-900">{markdown}</Markdown>
          )}
      </div>
    </div>
  )
}
