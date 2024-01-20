"use client";
import React from "react";
import { Card, Button, Dialog, DialogPanel, Title } from "@tremor/react";
import { InformationCircleIcon, ExternalLinkIcon, DotsHorizontalIcon, BookOpenIcon } from "@heroicons/react/outline";
import { Divider } from "@tremor/react";
import { CheckCircleIcon, ExclamationIcon, } from "@heroicons/react/outline";
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
              {props.Item.ScriptBlock}
              {props.Item.HelpUrl &&
                <div className="mb-3 text-right">
                  <Button icon={ExternalLinkIcon} variant="light" onClick={() => openInNewTab(props.Item.HelpUrl)}>
                    Learn more
                  </Button>
                </div>
              }
            </Card>
            {props.Item.ErrorRecord &&
              <Card className="mt-4">
                <Title>Reason for failure</Title>
                {props.Item.ErrorRecord}
              </Card>
            }
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