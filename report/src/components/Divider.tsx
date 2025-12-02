// Tremor Divider [v0.0.2]

import React from "react"
import { cx } from "@/lib/utils"

type DividerProps = React.ComponentPropsWithoutRef<"div">

const Divider = React.forwardRef<HTMLDivElement, DividerProps>(
  ({ className, children, ...props }, forwardedRef) => (
    <div
      ref={forwardedRef}
      className={cx(
        "mx-auto my-6 flex w-full items-center justify-between gap-3 text-sm",
        "text-gray-500 dark:text-gray-400",
        className,
      )}
      {...props}
    >
      {children ? (
        <>
          <div
            className={cx(
              "h-px w-full",
              "bg-gradient-to-r from-transparent to-gray-200 dark:to-gray-700",
            )}
          />
          <div className="whitespace-nowrap text-inherit">{children}</div>
          <div
            className={cx(
              "h-px w-full",
              "bg-gradient-to-l from-transparent to-gray-200 dark:to-gray-700",
            )}
          />
        </>
      ) : (
        <div
          className={cx(
            "h-px w-full",
            "bg-gradient-to-l from-transparent via-gray-200 to-transparent dark:via-gray-700",
          )}
        />
      )}
    </div>
  ),
)

Divider.displayName = "Divider"

export { Divider }
