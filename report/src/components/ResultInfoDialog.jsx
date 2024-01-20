"use client";
import React from "react";
import { Card, Button, Dialog, DialogPanel, Title, Text, Flex } from "@tremor/react";
import { ExternalLinkIcon, DotsHorizontalIcon } from "@heroicons/react/outline";
import { Divider } from "@tremor/react";
import StatusLabel from "./StatusLabel";

export default function ResultInfoDialog(props) {
  const [isOpen, setIsOpen] = React.useState(false);

  const openInNewTab = (url) => {
    window.open(url, "_blank", "noreferrer");
  };

  return (
    <>
      <div className="text-right">
        <Button size="xs" variant="secondary" color="gray" tooltip="View details" icon={DotsHorizontalIcon} onClick={() => setIsOpen(true)}></Button>
      </div>
      <Dialog open={isOpen} onClose={(val) => setIsOpen(val)} static={true}>
        <DialogPanel className="max-w-3xl">
          <div className="grid grid-cols-1">
            <div className="text-right">
              <StatusLabel Result={props.Item.Result} />
            </div>
            <Title>{props.Item.Name}</Title>
            <Divider></Divider>
            <Card>
              <Title>Test</Title>
              <Text className="break-words">{props.Item.ScriptBlock}</Text>
              {props.Item.HelpUrl &&
                <div className="mb-3 text-right">
                  <Button icon={ExternalLinkIcon} variant="light" onClick={() => openInNewTab(props.Item.HelpUrl)}>
                    Learn more
                  </Button>
                </div>
              }
            </Card>
            {props.Item.ErrorRecord && props.Item.ErrorRecord.length !== 0 &&
              <Card className="mt-4 break-words">
                <Title>Reason for failure</Title>
                <Text>{props.Item.ErrorRecord}</Text>
              </Card>
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
      </Dialog>
    </>
  );
}