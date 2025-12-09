"use client";
import React, { useEffect, useCallback } from "react";
import { ChevronLeftIcon, ChevronRightIcon } from "@heroicons/react/24/outline";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
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
  currentIndex?: number;
  totalCount?: number;
}

function ResultInfoSheet({
  Item,
  isOpen,
  onClose,
  onNavigateNext,
  onNavigatePrevious,
  currentIndex,
  totalCount,
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
        {/* Navigation buttons in the header area, positioned to the right of the close button */}
        <div className="absolute left-10 top-4 flex items-center gap-1">
          <button
            onClick={onNavigatePrevious}
            disabled={!onNavigatePrevious}
            className="rounded-sm p-1 opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:pointer-events-none disabled:opacity-30"
            title="Previous result (Left arrow key)"
          >
            <ChevronLeftIcon className="h-4 w-4" />
            <span className="sr-only">Previous</span>
          </button>
          {currentIndex !== undefined && totalCount !== undefined && (
            <span className="text-xs text-muted-foreground tabular-nums px-1">
              {currentIndex}/{totalCount}
            </span>
          )}
          <button
            onClick={onNavigateNext}
            disabled={!onNavigateNext}
            className="rounded-sm p-1 opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:pointer-events-none disabled:opacity-30"
            title="Next result (Right arrow key)"
          >
            <ChevronRightIcon className="h-4 w-4" />
            <span className="sr-only">Next</span>
          </button>
        </div>

        <SheetHeader className="sr-only">
          <SheetTitle>{Item.Title || Item.Name}</SheetTitle>
          <SheetDescription>Test result details</SheetDescription>
        </SheetHeader>

        <div className="mt-2">
          <ResultInfo Item={Item} isPrintView={false} />
        </div>
      </SheetContent>
    </Sheet>
  );
}

export default React.memo(ResultInfoSheet);
