import { DocumentChartBarIcon } from "@heroicons/react/24/outline"
import { Button } from "@/components/ui/report"
import { useNavigate } from "@/lib/router"
import { getAttachmentPath, type ReportAttachment } from "@/lib/reportAttachments"

/** One button per embedded report; each shows its report in the main panel. */
export default function ReportAttachmentButtons({ attachments, className }: { attachments: ReportAttachment[]; className?: string }) {
  const navigate = useNavigate()
  if (attachments.length === 0) return null
  return (
    <div className={className ?? "flex flex-wrap gap-2"}>
      {attachments.map((attachment) => (
        <Button
          key={attachment.Id}
          variant="secondary"
          icon={DocumentChartBarIcon}
          tooltip={`Show ${attachment.Name}`}
          onClick={() => navigate(getAttachmentPath(attachment))}
        >
          {attachment.Name}
        </Button>
      ))}
    </div>
  )
}
