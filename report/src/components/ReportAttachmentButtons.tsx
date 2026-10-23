import { ArrowTopRightOnSquareIcon } from "@heroicons/react/24/outline"
import { Button } from "@/components/ui/report"
import { openReportAttachment, type ReportAttachment } from "@/lib/reportAttachments"

/** One button per embedded report; each opens its report in a new tab. */
export default function ReportAttachmentButtons({ attachments, className }: { attachments: ReportAttachment[]; className?: string }) {
  if (attachments.length === 0) return null
  return (
    <div className={className ?? "flex flex-wrap gap-2"}>
      {attachments.map((attachment) => (
        <Button
          key={attachment.Id}
          variant="secondary"
          icon={ArrowTopRightOnSquareIcon}
          iconPosition="right"
          tooltip={`Open ${attachment.Name} in a new tab`}
          onClick={() => openReportAttachment(attachment)}
        >
          {attachment.Name}
        </Button>
      ))}
    </div>
  )
}
