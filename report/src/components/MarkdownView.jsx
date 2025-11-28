import React, { useState } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { Button, Tab, TabGroup, TabList, TabPanel, TabPanels } from "@tremor/react";
import { ClipboardDocumentIcon, EyeIcon, CodeBracketIcon } from "@heroicons/react/24/outline";

export default function MarkdownView({ testResults }) {
  const [markdown, setMarkdown] = useState(generateMarkdown(testResults));

  function generateMarkdown(results) {
    const testDateLocal = new Date(results.ExecutedAt).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
    const tenantName = results.TenantName ? `${results.TenantName} (${results.TenantId})` : `Tenant ID: ${results.TenantId}`;

    let md = `# Maester Test Results\n\n`;
    md += `**Tenant:** ${tenantName}  \n`;
    md += `**Date:** ${testDateLocal}\n\n`;

    md += `## Test Summary\n\n`;
    md += `| Total | Passed | Failed | Skipped | Not Run | Error |\n`;
    md += `| :---: | :---: | :---: | :---: | :---: | :---: |\n`;
    md += `| ${results.TotalCount} | ${results.PassedCount} | ${results.FailedCount} | ${results.SkippedCount} | ${results.NotRunCount} | ${results.ErrorCount} |\n\n`;

    md += `## Test Results\n\n`;
    md += `| Name | Severity | Result |\n`;
    md += `| :--- | :---: | :---: |\n`;
    results.Tests.forEach(test => {
      const icon = test.Result === 'Passed' ? '✅' : test.Result === 'Failed' ? '❌' : test.Result === 'Skipped' ? '⏭️' : '⚠️';
      // Escape pipes in the name to prevent breaking the table
      const safeName = test.Name.replace(/\|/g, '\\|');
      md += `| ${safeName} | ${test.Severity} | ${test.Result} |\n`;
    });
    md += `\n`;

    md += `## Test Details\n\n`;

    results.Tests.forEach(test => {
      const icon = test.Result === 'Passed' ? '✅' : test.Result === 'Failed' ? '❌' : test.Result === 'Skipped' ? '⏭️' : '⚠️';
      md += `### ${icon} ${test.Name}\n\n`;
      md += `**Result:** ${test.Result}  \n`;
      md += `**Severity:** ${test.Severity}  \n`;
      if (test.HelpUrl) {
        md += `**Help:** [Link](${test.HelpUrl})\n`;
      }
      md += `\n`;

      if (test.ResultDetail) {
        if (test.ResultDetail.TestDescription) {
            md += `${test.ResultDetail.TestDescription}\n\n`;
        }
        if (test.ResultDetail.TestResult) {
            md += `**Output:**\n\n${test.ResultDetail.TestResult}\n\n`;
        }
      }
      md += `---\n\n`;
    });

    return md;
  }

  const copyToClipboard = () => {
    navigator.clipboard.writeText(markdown);
  };

  return (
    <div className="p-8 max-w-5xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">Markdown</h1>
        <Button icon={ClipboardDocumentIcon} onClick={copyToClipboard}>
          Copy Markdown
        </Button>
      </div>

      <TabGroup defaultIndex={1}>
        <TabList className="mt-8">
          <Tab icon={CodeBracketIcon}>Markdown</Tab>
          <Tab icon={EyeIcon}>Preview</Tab>
        </TabList>
        <TabPanels>
          <TabPanel>
            <div className="mt-4">
              <textarea
                className="w-full h-[80vh] p-4 font-mono text-sm border rounded-md bg-gray-50 dark:bg-gray-900 dark:text-gray-100"
                value={markdown}
                onChange={(e) => setMarkdown(e.target.value)}
              />
            </div>
          </TabPanel>
          <TabPanel>
            <div className="mt-4 prose dark:prose-invert max-w-none p-4 border rounded-md bg-white dark:bg-gray-900">
              <ReactMarkdown remarkPlugins={[remarkGfm]}>
                {markdown}
              </ReactMarkdown>
            </div>
          </TabPanel>
        </TabPanels>
      </TabGroup>
    </div>
  );
}
