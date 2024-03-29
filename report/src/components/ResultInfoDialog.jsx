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
  function truncateText(text) {
    var maxLength = 120;
    if (text.length <= maxLength) return text;
    var truncated = text.substring(0, 120) + "...";
    return truncated;
  }

  return (
    <>
      {props.Title &&
        <button onClick={() => setIsOpen(true)} class="text-left tremor-Button-root font-medium outline-none text-sm text-gray-500 bg-transparent hover:text-gray-700 truncate">
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
              <div className="text-left">
                <Button icon={ArrowTopRightOnSquareIcon} variant="light" onClick={() => openInNewTab(props.Item.HelpUrl)}>
                  Learn more
                </Button>
              </div>
            }
            <Divider></Divider>

            {props.Item.ResultDetail &&
              <>
                <Card>
                  <Title>Overview</Title>
                  <Markdown className="prose max-w-fit dark:prose-invert" remarkPlugins={[remarkGfm]}>{props.Item.ResultDetail.TestDescription}</Markdown>
                </Card>
                <Card className="mt-4 break-words">
                  <Title>Test Results</Title>
                  <Markdown className="prose max-w-fit dark:prose-invert" remarkPlugins={[remarkGfm]}>{props.Item.ResultDetail.TestResult}</Markdown>
                </Card>
              </>
            }

            {!props.Item.ResultDetail &&
              <>
                <Card>
                  <Title>Test</Title>
                  <Text className="break-words">{props.Item.ScriptBlock}</Text>

                </Card>
                {props.Item.ErrorRecord &&
                  <Card className="mt-4 break-words">
                    <Title>Reason for failure</Title>
                    <Text>{props.Item.ErrorRecord}</Text>
                  </Card>
                }
              </>
            }
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