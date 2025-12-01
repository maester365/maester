import { useState } from "react"
import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"
import { Button } from "@/components/Button"
import { Dialog, DialogPanel, Tab, TabGroup, TabList, TabPanel, TabPanels } from "@tremor/react"
import { RiClipboardLine, RiEyeLine, RiCodeLine, RiCheckLine } from "@remixicon/react"
import { testResults } from "@/lib/testResults"

function generateMarkdown(results: typeof testResults) {
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
  md += `| Total | Passed | Failed | Skipped | Not Run | Error |\n`
  md += `| :---: | :---: | :---: | :---: | :---: | :---: |\n`
  md += `| ${results.TotalCount} | ${results.PassedCount} | ${results.FailedCount} | ${results.SkippedCount} | ${results.NotRunCount || 0} | ${results.ErrorCount || 0} |\n\n`

  md += `## Test Results\n\n`
  md += `| Name | Severity | Result |\n`
  md += `| :--- | :---: | :---: |\n`
  results.Tests.forEach((test) => {
    const safeName = test.Name.replace(/\|/g, "\\|")
    md += `| ${safeName} | ${test.Severity} | ${test.Result} |\n`
  })
  md += `\n`

  md += `## Test Details\n\n`

  results.Tests.forEach((test) => {
    const icon =
      test.Result === "Passed"
        ? "✅"
        : test.Result === "Failed"
          ? "❌"
          : test.Result === "Skipped"
            ? "⏭️"
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
  const [markdown, setMarkdown] = useState(generateMarkdown(testResults))
  const [isDialogOpen, setIsDialogOpen] = useState(false)

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

      <TabGroup defaultIndex={1}>
        <TabList className="mt-8">
          <Tab icon={RiCodeLine}>Markdown</Tab>
          <Tab icon={RiEyeLine}>Preview</Tab>
        </TabList>
        <TabPanels>
          <TabPanel>
            <div className="mt-4">
              <textarea
                className="h-[80vh] w-full rounded-md border border-gray-200 bg-white p-4 font-mono text-sm text-gray-900 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
                value={markdown}
                onChange={(e) => setMarkdown(e.target.value)}
              />
            </div>
          </TabPanel>
          <TabPanel>
            <div className="prose mt-4 max-w-none rounded-md border border-gray-200 bg-white p-4 dark:prose-invert dark:border-gray-700 dark:bg-gray-900">
              <ReactMarkdown remarkPlugins={[remarkGfm]}>
                {markdown}
              </ReactMarkdown>
            </div>
          </TabPanel>
        </TabPanels>
      </TabGroup>
    </div>
  )
}
