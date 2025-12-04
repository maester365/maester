import React, { useCallback } from "react";
import { Card, Button, Title, Text, Flex, Divider } from "@tremor/react";
import { ArrowTopRightOnSquareIcon } from "@heroicons/react/24/outline";
import StatusLabel from "./StatusLabel";
import StatusLabelSm from "./StatusLabelSm";
import SeverityBadge from "./SeverityBadge";
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

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
      return "bg-green-100 dark:bg-green-900 dark:bg-opacity-40";
    }
    if (result === "Failed") {
      return "bg-red-100 dark:bg-red-900 dark:bg-opacity-30";
    }
    if (result === "Skipped") {
      return "bg-yellow-100";
    }
    return "bg-gray-100";
  }

  return (
    <div className="grid grid-cols-1" id={Item.Id}>
      <div className="text-right flex justify-end space-x-2 items-center">
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
        <Markdown className="prose max-w-fit dark:prose-invert" remarkPlugins={[remarkGfm]}>{getTestResult()}</Markdown>
      </Card>
      <Card className="mt-4 bg-slate-50">
        <Title>Test details</Title>
        <Markdown className="prose max-w-fit dark:prose-invert" remarkPlugins={[remarkGfm]}>{getTestDetails()}</Markdown>
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
          </Card>
        </>
      )}
    </div>
  );
}
