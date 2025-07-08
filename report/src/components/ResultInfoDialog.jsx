"use client";
import React, { useEffect, useCallback } from "react";
import { Card, Button, Dialog, DialogPanel, Title, Text, Flex } from "@tremor/react";
import { ArrowTopRightOnSquareIcon, WindowIcon, ChevronLeftIcon, ChevronRightIcon } from "@heroicons/react/24/outline";
import { Divider } from "@tremor/react";
import StatusLabel from "./StatusLabel";
import StatusLabelSm from "./StatusLabelSm";
import SeverityBadge from "./SeverityBadge";
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

// We've removed the global dialog state manager since we now use a single dialog instance

function ResultInfoDialog(props) {
  const itemIndex = props.Item.Index;
  // Control dialog state based on parent control only
  const [isOpen, setIsOpen] = React.useState(props.isOpen);

  const openInNewTab = useCallback((url) => {
    window.open(url, "_blank", "noreferrer");
  }, []);

  // Only update local state when props.isOpen changes, not when isOpen changes
  useEffect(() => {
    setIsOpen(props.isOpen);
  }, [props.isOpen]);
  // Memoize the keyboard handler to prevent recreating it on every render
  const handleKeyboard = useCallback((event) => {
    if (!isOpen) return;

    if (event.key === 'ArrowRight') {
      event.preventDefault();
      if (props.onNavigateNext) {
        props.onNavigateNext(itemIndex);
      }
    } else if (event.key === 'ArrowLeft') {
      event.preventDefault();
      if (props.onNavigatePrevious) {
        props.onNavigatePrevious(itemIndex);
      }
    }
  }, [isOpen, props.onNavigateNext, props.onNavigatePrevious, itemIndex]);

  // Add and remove the event listener
  useEffect(() => {
    if (isOpen) {
      window.addEventListener('keydown', handleKeyboard);
      return () => {
        window.removeEventListener('keydown', handleKeyboard);
      };
    }
  }, [isOpen, handleKeyboard]);
  // Since we're now controlled by the parent component, simplify these handlers
  const handleOpenDialog = useCallback(() => {
    if (props.onDialogOpen) {
      props.onDialogOpen(itemIndex);
    }
  }, [props.onDialogOpen, itemIndex]);

  const handleCloseDialog = useCallback(() => {
    if (props.onDialogClose) {
      props.onDialogClose();
    }
  }, [props.onDialogClose]);

  const navigateToNextResult = useCallback(() => {
    if (props.onNavigateNext) {
      props.onNavigateNext();
    }
  }, [props.onNavigateNext]);  // No need to pass itemIndex since parent already has access to it

  const navigateToPreviousResult = useCallback(() => {
    if (props.onNavigatePrevious) {
      props.onNavigatePrevious();
    }
  }, [props.onNavigatePrevious]);

  function getTestResult() {
    if (props.Item.ResultDetail) {
      return props.Item.ResultDetail.TestResult;
    }
    else if (props.Item.ResultDetail) {
      return props.Item.ResultDetail;
    }
    else {
      if (props.Item.Result === "Passed") {
        return "Tested successfully.";
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
              {props.Item.Severity && (
                <div title="Severity" className="flex items-center">
                  <SeverityBadge Severity={props.Item.Severity} />
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

export default React.memo(ResultInfoDialog);