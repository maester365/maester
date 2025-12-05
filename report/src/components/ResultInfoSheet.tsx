"use client";
import React, { useEffect, useCallback } from "react";
import { Button } from "@tremor/react";
import { ChevronLeftIcon, ChevronRightIcon } from "@heroicons/react/24/outline";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
  SheetFooter,
} from "@/components/ui/sheet";
import ResultInfo from "./ResultInfo";

interface ResultInfoSheetProps {
  Item: {
    Index: number;
    Name: string;
    Title?: string;
    Id?: string;
    [key: string]: unknown;
  } | null;
  isOpen: boolean;
  onClose: () => void;
  onNavigateNext?: () => void;
  onNavigatePrevious?: () => void;
}

function ResultInfoSheet({
  Item,
  isOpen,
  onClose,
  onNavigateNext,
  onNavigatePrevious,
}: ResultInfoSheetProps) {
  // Memoize the keyboard handler to prevent recreating it on every render
  const handleKeyboard = useCallback(
    (event: KeyboardEvent) => {
      if (!isOpen) return;

      if (event.key === "ArrowRight") {
        event.preventDefault();
        if (onNavigateNext) {
          onNavigateNext();
        }
      } else if (event.key === "ArrowLeft") {
        event.preventDefault();
        if (onNavigatePrevious) {
          onNavigatePrevious();
        }
      }
    },
    [isOpen, onNavigateNext, onNavigatePrevious]
  );

  // Add and remove the event listener
  useEffect(() => {
    if (isOpen) {
      window.addEventListener("keydown", handleKeyboard);
      return () => {
        window.removeEventListener("keydown", handleKeyboard);
      };
    }
  }, [isOpen, handleKeyboard]);

  // Don't render anything if no item has ever been selected
  if (!Item) {
    return null;
  }

  return (
    <Sheet open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        side="right"
        className="w-full sm:max-w-2xl lg:max-w-4xl overflow-y-auto"
      >
        <SheetHeader className="sr-only">
          <SheetTitle>{Item.Title || Item.Name}</SheetTitle>
          <SheetDescription>Test result details</SheetDescription>
        </SheetHeader>

        <div className="mt-2">
          <ResultInfo Item={Item} isPrintView={false} />
        </div>

        <SheetFooter className="mt-6 flex-row justify-between sm:justify-between gap-2">
          <Button
            variant="secondary"
            icon={ChevronLeftIcon}
            onClick={onNavigatePrevious}
            disabled={!onNavigatePrevious}
            className="flex-1 sm:flex-none"
          >
            Previous
          </Button>
          <Button
            variant="secondary"
            icon={ChevronRightIcon}
            iconPosition="right"
            onClick={onNavigateNext}
            disabled={!onNavigateNext}
            className="flex-1 sm:flex-none"
          >
            Next
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}

export default React.memo(ResultInfoSheet);
