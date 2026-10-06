import { Badge } from "@/components/ui/report"
import { getReasonInfo } from "@/lib/resultSchema"
import { cn } from "@/lib/utils"

// Why a test was skipped, not run or errored (result schema 2.1). Renders nothing for 2.x rows.
export function ReasonBadge({ code, detail, className }: { code?: string | null; detail?: string | null; className?: string }) {
  if (!code) return null
  const info = getReasonInfo(code)
  return (
    // The tooltip is plain text, so markdown links in the detail keep only their text.
    <span title={detail ? detail.replace(/\[([^\]]*)\]\([^)]*\)/g, "$1") : info.description} className={cn("inline-flex", className)}>
      <Badge color={info.color} size="xs">{info.label}</Badge>
    </span>
  )
}

// Native or Pester test. Renders nothing for 2.x rows, which have no Format.
export function FormatBadge({ format, className }: { format?: string | null; className?: string }) {
  if (!format) return null
  const isNative = format === "Native"
  return (
    <span
      title={isNative ? "Native Maester test" : `${format} test`}
      className={cn(
        "inline-flex shrink-0 items-center rounded px-1.5 py-px text-[10px] font-medium uppercase tracking-wide ring-1 ring-inset",
        isNative
          ? "bg-blue-500/10 text-blue-600 ring-blue-500/20 dark:text-blue-400 dark:ring-blue-500/40"
          : "bg-gray-500/10 text-gray-600 ring-gray-500/20 dark:text-gray-400 dark:ring-gray-500/40",
        className,
      )}
    >
      {format}
    </span>
  )
}
