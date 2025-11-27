import React from 'react';
import { Button } from "@tremor/react";
import { ClipboardDocumentIcon } from "@heroicons/react/24/outline";

export default function ExcelView({ testResults }) {
  const copyToClipboard = () => {
    const headers = ['ID', 'Title', 'Severity', 'Status', 'Category', 'Description', 'Result', 'Tags', 'Notes'];
    const rows = testResults.Tests.map(test => {
        return [
            test.Id,
            test.Title,
            test.Severity,
            test.Result,
            test.Block,
            test.ResultDetail?.TestDescription,
            test.ResultDetail?.TestResult,
            test.Tag?.join(', '),
            test.ResultDetail?.SkippedReason
        ].map(field => {
            if (field == null) return '';
            let str = String(field);
            // Replace tabs and newlines to ensure it pastes correctly into Excel cells
            str = str.replace(/\t/g, ' ').replace(/(\r\n|\n|\r)/g, ' ');
            return str;
        }).join('\t');
    });

    const tsv = [headers.join('\t'), ...rows].join('\n');

    navigator.clipboard.writeText(tsv).then(() => {
        // You might want to show a toast or notification here
        // alert("Copied to clipboard!");
    }).catch(err => {
        console.error('Failed to copy: ', err);
    });
  };

  return (
    <div className="p-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">Excel</h1>
        <Button icon={ClipboardDocumentIcon} onClick={copyToClipboard}>
          Copy to Excel
        </Button>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full text-sm text-left text-gray-500 dark:text-gray-400 border-collapse border border-gray-200">
            <thead className="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
                <tr>
                    <th className="border border-gray-300 p-2">ID</th>
                    <th className="border border-gray-300 p-2">Title</th>
                    <th className="border border-gray-300 p-2">Severity</th>
                    <th className="border border-gray-300 p-2">Status</th>
                    <th className="border border-gray-300 p-2">Category</th>
                    <th className="border border-gray-300 p-2">Description</th>
                    <th className="border border-gray-300 p-2">Result</th>
                    <th className="border border-gray-300 p-2">Tags</th>
                    <th className="border border-gray-300 p-2">Notes</th>
                </tr>
            </thead>
            <tbody>
                {testResults.Tests.map((test, index) => {
                    return (
                        <tr key={index} className="bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600">
                            <td className="border border-gray-300 p-2 font-medium text-gray-900 dark:text-white max-w-40 truncate">{test.Id}</td>
                            <td className="border border-gray-300 p-2">{test.Title}</td>
                            <td className="border border-gray-300 p-2">{test.Severity}</td>
                            <td className="border border-gray-300 p-2 max-w-xs truncate">{test.Result}</td>
                            <td className="border border-gray-300 p-2 max-w-20 truncate">{test.Block}</td>
                            <td className="border border-gray-300 p-2 max-w-xs truncate" title={test.ResultDetail?.TestDescription}>{test.ResultDetail?.TestDescription}</td>
                            <td className="border border-gray-300 p-2 max-w-xs truncate" >{test.ResultDetail?.TestResult}</td>
                            <td className="border border-gray-300 p-2">{test.Tag?.join(', ')}</td>
                            <td className="border border-gray-300 p-2 max-w-xs truncate">{test.ResultDetail?.SkippedReason}</td>
                        </tr>
                    );
                })}
            </tbody>
        </table>
      </div>
    </div>
  );
}
