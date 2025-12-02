import clsx from "clsx";
import { twMerge } from "tailwind-merge";

export function cx(...args) {
  return twMerge(clsx(...args));
}

export const focusInput = [
  // base
  "focus:ring-2",
  // ring color
  "focus:ring-orange-200 dark:focus:ring-orange-700/30",
  // border color
  "focus:border-orange-500 dark:focus:border-orange-700",
];

export const focusRing = [
  // base
  "outline outline-offset-2 outline-0 focus-visible:outline-2",
  // outline color
  "outline-orange-500 dark:outline-orange-500",
];
