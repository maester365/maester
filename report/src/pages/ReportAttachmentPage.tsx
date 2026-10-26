import { useEffect, useRef, useState } from "react"
import { ArrowTopRightOnSquareIcon } from "@heroicons/react/24/outline"
import { Button } from "@/components/ui/report"
import { useTenant } from "@/context/TenantContext"
import { useLocation } from "@/lib/router"
import { attachmentSandbox, findReportAttachment, openReportAttachment, writeAttachmentToFrame } from "@/lib/reportAttachments"

/** A report embedded with Add-MtReportAttachment, shown in the main panel beside the navigation. */
export default function ReportAttachmentPage() {
  const { selectedTenant } = useTenant()
  const { pathname } = useLocation()
  const attachment = findReportAttachment(selectedTenant, pathname)
  const frameRef = useRef<HTMLIFrameElement>(null)
  const [error, setError] = useState<string>()

  useEffect(() => {
    setError(undefined)
    if (!attachment || !frameRef.current) return
    writeAttachmentToFrame(attachment, frameRef.current).catch((reason: unknown) =>
      setError(reason instanceof Error ? reason.message : String(reason))
    )
  }, [attachment?.Id])

  if (!attachment) {
    return (
      <div className="p-6 text-sm text-gray-500 dark:text-gray-400">
        This report is not embedded in this file{selectedTenant?.TenantName ? ` for ${selectedTenant.TenantName}` : ""}.
      </div>
    )
  }

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center justify-between gap-4 border-b border-gray-200 bg-white px-6 py-2 dark:border-gray-800 dark:bg-black">
        <p className="truncate text-sm text-gray-500 dark:text-gray-400">
          {attachment.FileName ? `${attachment.Name} · ${attachment.FileName}` : attachment.Name}
        </p>
        <Button variant="light" icon={ArrowTopRightOnSquareIcon} onClick={() => openReportAttachment(attachment)}>
          Open in new tab
        </Button>
      </div>
      {error ? (
        <p className="p-6 text-sm text-red-600 dark:text-red-400">{attachment.Name} could not be shown: {error}</p>
      ) : (
        <iframe key={attachment.Id} ref={frameRef} title={attachment.Name} sandbox={attachmentSandbox} className="w-full flex-1 border-0 bg-white" />
      )}
    </div>
  )
}
