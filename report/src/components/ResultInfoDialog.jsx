"use client";
import React, { useEffect } from "react";
import { Card, Button, Dialog, DialogPanel, Title, Text, Flex } from "@tremor/react";
import { ArrowTopRightOnSquareIcon, WindowIcon, ChevronLeftIcon, ChevronRightIcon } from "@heroicons/react/24/outline";
import { Divider } from "@tremor/react";
import StatusLabel from "./StatusLabel";
import StatusLabelSm from "./StatusLabelSm";
import SeverityBadge from "./SeverityBadge";
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

// Global dialog state manager
const dialogState = {
  currentOpenItemId: null,
};

export default function ResultInfoDialog(props) {
  const itemId = props.Item.Id || props.Item.Name;
  // Control dialog state based on either direct interaction or parent control
  const [isOpen, setIsOpen] = React.useState(false);

  const openInNewTab = (url) => {
    window.open(url, "_blank", "noreferrer");
  };

  // Handle dialog open/close from parent via the activeDialog prop
  useEffect(() => {
    // If this is the active dialog that should be opened
    if (props.activeDialog === itemId) {
      setIsOpen(true);
    }
    // If another dialog is being opened, or no dialog should be active, close this one
    else if (isOpen && props.activeDialog !== itemId) {
      setIsOpen(false);
    }
  }, [props.activeDialog, itemId, isOpen]);

  // Update global dialog state when this dialog opens/closes
  useEffect(() => {
    if (isOpen) {
      dialogState.currentOpenItemId = itemId;
    } else if (dialogState.currentOpenItemId === itemId) {
      dialogState.currentOpenItemId = null;
    }
  }, [isOpen, itemId]);

  // Handle keyboard navigation events
  useEffect(() => {
    const handleKeyboard = (event) => {
      // Only handle keyboard events if this dialog is currently open
      if (!isOpen) return;

      if (event.key === 'ArrowRight') {
        event.preventDefault();
        if (props.onNavigateNext) {
          props.onNavigateNext(itemId);
        }
      } else if (event.key === 'ArrowLeft') {
        event.preventDefault();
        if (props.onNavigatePrevious) {
          props.onNavigatePrevious(itemId);
        }
      }
    };

    if (isOpen) {
      window.addEventListener('keydown', handleKeyboard);
    }

    return () => {
      window.removeEventListener('keydown', handleKeyboard);
    };
  }, [isOpen, props.onNavigateNext, props.onNavigatePrevious, itemId]);

  // Handle opening the dialog
  const handleOpenDialog = () => {
    // Tell the parent table that this is the active dialog
    if (props.onDialogOpen) {
      props.onDialogOpen(itemId);
    }
    setIsOpen(true);
  };

  // Handle closing the dialog
  const handleCloseDialog = () => {
    if (props.onDialogClose) {
      props.onDialogClose();
    }
    setIsOpen(false);
  };

  // Navigation handlers
  const navigateToNextResult = () => {
    if (props.onNavigateNext) {
      props.onNavigateNext(itemId);
    }
  };

  const navigateToPreviousResult = () => {
    if (props.onNavigatePrevious) {
      props.onNavigatePrevious(itemId);
    }
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
        <button onClick={handleOpenDialog} className="text-left tremor-Button-root font-medium outline-none text-sm text-gray-500 bg-transparent hover:text-gray-700 truncate">
          <span className="truncate whitespace-normal tremor-Button-text text-tremor-default">{props.Item.Name}</span>
        </button>
      }
      {props.DisplayText !== undefined &&
        <button onClick={handleOpenDialog} className="text-left tremor-Button-root font-medium outline-none text-sm bg-transparent hover:text-blue-600 transition-colors">
          <span className="whitespace-normal tremor-Button-text text-tremor-default">{props.DisplayText}</span>
        </button>
      }
      {props.Button &&
        <div className="text-right">
          <Button
            size="xs"
            variant="secondary"
            color="gray"
            tooltip="View details"
            icon={WindowIcon}
            onClick={handleOpenDialog}
          />
        </div>
      }
      <Dialog open={isOpen} onClose={handleCloseDialog} static={true}>
        <DialogPanel className="max-w-4xl">
          <div className="grid grid-cols-1">
            <div className="text-right flex justify-end space-x-2 items-center">
              {props.Item.ResultDetail && props.Item.ResultDetail.Severity && (
                <div title="Severity" className="flex items-center">
                  <SeverityBadge Severity={props.Item.ResultDetail.Severity} />
                </div>
              )}
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
                {props.Item.Tag && props.Item.Tag.map((item) => (
                  <Text key={item} className="mr-3">{item}</Text>
                ))}
              </Flex>
            </Card>
            <Card className="mt-4">
              <Title>Source</Title>
              <Text>{props.Item.ScriptBlockFile}</Text>
            </Card>

            <Flex className="mt-6 justify-between">
              <Button
                variant="secondary"
                icon={ChevronLeftIcon}
                onClick={navigateToPreviousResult}
                disabled={!props.onNavigatePrevious}
                tooltip="Previous result (Left arrow key)"
              >
                Previous
              </Button>
              <Button variant="primary" onClick={handleCloseDialog}>
                Close
              </Button>
              <Button
                variant="secondary"
                icon={ChevronRightIcon}
                iconPosition="right"
                onClick={navigateToNextResult}
                disabled={!props.onNavigateNext}
                tooltip="Next result (Right arrow key)"
              >
                Next
              </Button>
            </Flex>
          </div>
        </DialogPanel>
      </Dialog>
    </>
  );
}