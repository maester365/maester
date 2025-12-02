"use client";
import React, { useEffect, useCallback } from "react";
import { Button, Dialog, DialogPanel, Flex } from "@tremor/react";
import { WindowIcon, ChevronLeftIcon, ChevronRightIcon } from "@heroicons/react/24/outline";
import ResultInfo from "./ResultInfo";

// We've removed the global dialog state manager since we now use a single dialog instance

function ResultInfoDialog(props) {
  const itemIndex = props.Item.Index;
  // Control dialog state based on parent control only
  const [isOpen, setIsOpen] = React.useState(props.isOpen);

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
          <ResultInfo Item={props.Item} />

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
        </DialogPanel>
      </Dialog>
    </>
  );
}

export default React.memo(ResultInfoDialog);