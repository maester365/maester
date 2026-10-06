import React, { useCallback } from "react";
import { Card, Button, Title, Text, Flex, Divider } from "@/components/ui/report";
import { ArrowTopRightOnSquareIcon } from "@heroicons/react/24/outline";
import StatusLabel from "./StatusLabel";
import StatusLabelSm from "./StatusLabelSm";
import SeverityBadge from "./SeverityBadge";
import { Markdown } from '@/components/Markdown'
import { FormatBadge, ReasonBadge } from "./ResultBadges";
import { asArray, formatValue, getParentId, getReasonInfo } from "@/lib/resultSchema";

// Result schema 2.1 details: why the test did not run or errored, its family, parameters and diagnostics.
// Each card renders only when the row has the field, so 2.x results look as before.
function ResultSchemaDetails({ Item }) {
  const parentId = getParentId(Item);
  const parameters = asArray(Item.Parameters).filter((p) => p && p.Name);
  const diagnostics = asArray(Item.Diagnostics).filter(Boolean);

  return (
    <>
      {Item.ReasonCode && (
        <Card className="mt-4">
          <div className="flex flex-row items-center gap-2">
            <Title>Reason</Title>
            <ReasonBadge code={Item.ReasonCode} detail={Item.ReasonDetail} />
          </div>
          {/* ReasonDetail can carry the test's skip text, which may contain markdown links. */}
          <Markdown className="prose prose-sm mt-2 max-w-fit dark:prose-invert">{Item.ReasonDetail || getReasonInfo(Item.ReasonCode).description}</Markdown>
          <Text className="mt-1 font-mono text-xs">{Item.ReasonCode}</Text>
        </Card>
      )}
      {(parentId || Item.InstanceId) && (
        <Card className="mt-4">
          <Title>Test family</Title>
          <dl className="mt-2 grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
            {parentId && (
              <div>
                <dt className="text-xs font-medium text-gray-500 dark:text-gray-400">Parent test</dt>
                <dd className="font-mono text-gray-900 dark:text-gray-100">{parentId}</dd>
              </div>
            )}
            {Item.InstanceId && (
              <div>
                <dt className="text-xs font-medium text-gray-500 dark:text-gray-400">Instance</dt>
                <dd className="font-mono text-gray-900 dark:text-gray-100">{Item.InstanceId}</dd>
              </div>
            )}
          </dl>
        </Card>
      )}
      {parameters.length > 0 && (
        <Card className="mt-4">
          <Title>Parameters</Title>
          <table className="mt-2 w-full text-left text-sm">
            <thead>
              <tr className="text-xs text-gray-500 dark:text-gray-400">
                <th className="py-1 pr-4 font-medium">Name</th>
                <th className="py-1 pr-4 font-medium">Value</th>
                <th className="py-1 font-medium">Source</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 dark:divide-zinc-800">
              {parameters.map((p) => (
                <tr key={p.Name}>
                  <td className="py-1 pr-4 font-mono text-gray-900 dark:text-gray-100">{p.Name}</td>
                  <td className="py-1 pr-4 break-all text-gray-700 dark:text-gray-300">{formatValue(p.Value)}</td>
                  <td className="py-1 text-gray-500 dark:text-gray-400">{p.Source || ""}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}
      {diagnostics.length > 0 && (
        <Card className="mt-4">
          <Title>Diagnostics</Title>
          <ul className="mt-2 space-y-1">
            {diagnostics.map((line, index) => (
              <li key={index} className="whitespace-pre-wrap break-words font-mono text-xs text-gray-700 dark:text-gray-300">{typeof line === "string" ? line : formatValue(line)}</li>
            ))}
          </ul>
        </Card>
      )}
    </>
  );
}

export default function ResultInfo({ Item, isPrintView }) {
  const openInNewTab = useCallback((url) => {
    window.open(url, "_blank", "noreferrer");
  }, []);

  function getTestResult() {
    if (Item.ResultDetail) {
      return Item.ResultDetail.TestResult;
    }
    else if (Item.ResultDetail) {
      return Item.ResultDetail;
    }
    else {
      if (Item.Result === "Passed") {
        return "Tested successfully.";
      }
      if (Item.Result === "Failed") {
        return "Test failed.";
      }
      if (Item.Result === "Skipped") {
        return "Test skipped.";
      }
      if (Item.Result === "Investigate") {
        return "Test requires investigation.";
      }
    }
    return "";
  }

  function getTestDetails() {
    if (Item.ResultDetail) {
      return Item.ResultDetail.TestDescription;
    }
    else {
      //trim the scriptblock whitespace at the beginning and end
      if (Item.ScriptBlock) {
        return Item.ScriptBlock.replace(/^\s+|\s+$/g, '');
      }
    }
    return "";
  }

  //Set bgcolor based on result
  function getBgColor(result) {
    if (result === "Passed") {
      return "bg-green-100 dark:bg-green-900/40";
    }
    if (result === "Failed") {
      return "bg-red-100 dark:bg-red-900/30";
    }
    if (result === "Skipped") {
      return "bg-yellow-100";
    }
    if (result === "Investigate") {
      return "bg-purple-100 dark:bg-purple-900/30";
    }
    return "bg-gray-100";
  }

  return (
    <div className="grid grid-cols-1" id={isPrintView ? Item.Id : undefined}>
      <div className="text-right flex justify-end space-x-2 items-center">
        <FormatBadge format={Item.Format} />
        {Item.Severity && (
          <div title="Severity" className="flex items-center">
            <SeverityBadge Severity={Item.Severity} />
          </div>
        )}
        <StatusLabel Result={Item.Result} />
      </div>
      <Title>{Item.Name}</Title>
      {!isPrintView && Item.HelpUrl &&
        <div className="text-left mt-2">
          <Button icon={ArrowTopRightOnSquareIcon} variant="light" onClick={() => openInNewTab(Item.HelpUrl)}>
            Learn more @ {new URL(Item.HelpUrl).hostname}
          </Button>
        </div>
      }
      <Divider></Divider>

      <Card className={"break-words " + getBgColor(Item.Result)}>
        <div className="flex flex-row items-center">
          <Title>Test result</Title><StatusLabelSm Result={Item.Result} />
        </div>
        <Markdown className="prose max-w-fit dark:prose-invert">{getTestResult()}</Markdown>
      </Card>
      <ResultSchemaDetails Item={Item} />
      <Card className="mt-4 bg-slate-50">
        <Title>Test details</Title>
        <Markdown className="prose max-w-fit dark:prose-invert">{getTestDetails()}</Markdown>
      </Card>

      {isPrintView ? (
        <div className="mt-4 grid grid-cols-2 gap-4">
          <Card>
            <Title>Category</Title>
            <Text>{Item.Block}</Text>
          </Card>
          <Card>
            <Title>Tags</Title>
            <Flex justifyContent="start" className="flex-wrap">
              {Item.Tag && Item.Tag.map((item) => (
                <Text key={item} className="mr-3">{item}</Text>
              ))}
            </Flex>
          </Card>
        </div>
      ) : (
        <>
          <Card className="mt-4">
            <Title>Category</Title>
            <Text>{Item.Block}</Text>
          </Card>
          <Card className="mt-4">
            <Title>Tags</Title>
            <Flex justifyContent="start">
              {Item.Tag && Item.Tag.map((item) => (
                <Text key={item} className="mr-3">{item}</Text>
              ))}
            </Flex>
          </Card>
          <Card className="mt-4">
            <Title>Source</Title>
            <Text>{Item.ScriptBlockFile}</Text>
            {(Item.Source || Item.Suite) && (
              <Text className="mt-1">
                {[Item.Source, Item.Suite].filter(Boolean).join(" / ")}
              </Text>
            )}
          </Card>
        </>
      )}
    </div>
  );
}
