"use client";
import React from "react";
import { Card, Button, Dialog, DialogPanel, Title, Text, Flex } from "@tremor/react";
import { ArrowTopRightOnSquareIcon, WindowIcon } from "@heroicons/react/24/outline";
import { Divider } from "@tremor/react";
import StatusLabel from "./StatusLabel";
import StatusLabelSm from "./StatusLabelSm";
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

export default function ResultInfoDialog(props) {
  const [isOpen, setIsOpen] = React.useState(false);

  const openInNewTab = (url) => {
    window.open(url, "_blank", "noreferrer");
  };

  function getTestResult() {

    if (props.Item.ResultDetail) {
      return props.Item.ResultDetail.TestResult;
    }
    else if (props.Item.ResultDetail) {
      return props.Item.ResultDetail;
    }
    else {
      if (props.Item.Result === "Passed") {
        return "Tested succesfully.";
      }
      if (props.Item.Result === "Failed") {
        return "Test failed.";
      }
      if (props.Item.Result === "Skipped") {
        return "Test skipped.";
      }
    }
    return "";
  }

  function getTestDetails() {
    if (props.Item.ResultDetail) {
      return props.Item.ResultDetail.TestDescription;
    }
    else {
      //trim the scriptblock whitespace at the beginning and end
      if (props.Item.ScriptBlock) {
        return props.Item.ScriptBlock.replace(/^\s+|\s+$/g, '');
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
    <>
      {props.Title &&
        <button onClick={() => setIsOpen(true)} className="text-left tremor-Button-root font-medium outline-none text-sm text-gray-500 bg-transparent hover:text-gray-700 truncate">
          <span className="truncate whitespace-normal tremor-Button-text text-tremor-default" >{props.Item.Name}</span>
        </button>
      }
      {props.Button &&
        <div className="text-right">
          <Button size="xs" variant="secondary" color="gray" tooltip="View details" icon={WindowIcon} onClick={() => setIsOpen(true)}></Button>
        </div>
      }
      <Dialog open={isOpen} onClose={(val) => setIsOpen(val)} static={true}>
        <DialogPanel className="max-w-4xl">
          <div className="grid grid-cols-1">
            <div className="text-right">
              <StatusLabel Result={props.Item.Result} />
            </div>
            <Title>{props.Item.Name}</Title>
            {props.Item.HelpUrl &&
              <div className="text-left mt-2">
                <Button icon={ArrowTopRightOnSquareIcon} variant="light" onClick={() => openInNewTab(props.Item.HelpUrl)}>
                  Learn more @ {new URL(props.Item.HelpUrl).hostname}
                </Button>
              </div>
            }
            <Divider></Divider>

            <Card className={"break-words " + getBgColor(props.Item.Result)}>
              <div className="flex flex-row items-center">
                <Title>Test result</Title><StatusLabelSm Result={props.Item.Result} />
              </div>
              <Markdown className="prose max-w-fit dark:prose-invert" remarkPlugins={[remarkGfm]}>{getTestResult()}</Markdown>
            </Card>
            <Card className="mt-4 bg-slate-50">
              <Title>Test details</Title>
              <Markdown className="prose max-w-fit dark:prose-invert" remarkPlugins={[remarkGfm]}>{getTestDetails()}</Markdown>
            </Card>

            <Card className="mt-4">
              <Title>Category</Title>
              <Text>{props.Item.Block}</Text>
            </Card>
            <Card className="mt-4">
              <Title>Tags</Title>
              <Flex justifyContent="start">
                {props.Item.Tag.map((item) => (
                  <Text className="mr-3">{item}</Text>
                ))}
              </Flex>
            </Card>
            <Card className="mt-4">
              <Title>Source</Title>
              <Text>{props.Item.ScriptBlockFile}</Text>
            </Card>
            <div className="mt-3">
              <Button variant="primary" onClick={() => setIsOpen(false)}>
                Close
              </Button>
            </div>
          </div>
        </DialogPanel>
      </Dialog >
    </>
  );
}