// Reports of other tools embedded with Add-MtReportAttachment. The report data lists each one; its content is
// gzip-compressed HTML, Base64-encoded, in a <script type="application/octet-stream"> element of its own.

export interface ReportAttachment {
  Id: string
  Name: string
  TestId?: string | null
  ContentType?: string
  FileName?: string | null
  Size?: number
}

const elementIdPrefix = "maester-attachment-"

function attachmentElement(attachment: ReportAttachment) {
  return document.getElementById(elementIdPrefix + attachment.Id)
}

/** The attachments of a result whose content is in this page (the dev server and imported JSON have none). */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function getReportAttachments(testResults: any): ReportAttachment[] {
  const attachments: ReportAttachment[] = Array.isArray(testResults?.Attachments) ? testResults.Attachments : []
  return attachments.filter((attachment) => attachment?.Id && attachment.Name && attachmentElement(attachment))
}

/** The report route that shows an attachment in the main panel. */
export function getAttachmentPath(attachment: ReportAttachment) {
  return `/reports/${encodeURIComponent(attachment.Id)}`
}

/** The attachment a /reports/<id> route names, or undefined. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function findReportAttachment(testResults: any, pathname: string): ReportAttachment | undefined {
  const match = /^\/reports\/([^/]+)$/.exec(pathname)
  if (!match) return undefined
  let id: string
  try {
    id = decodeURIComponent(match[1])
  } catch {
    // A mistyped or cut link names no attachment.
    return undefined
  }
  return getReportAttachments(testResults).find((attachment) => attachment.Id === id)
}

/** The attachments a test added, shown on that test's result and on each instance of a family. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function getTestAttachments(testResults: any, test: { Id?: string; ParentId?: string | null }): ReportAttachment[] {
  return getReportAttachments(testResults).filter(
    (attachment) => attachment.TestId && (attachment.TestId === test.Id || attachment.TestId === test.ParentId)
  )
}

const decoded = new Map<string, Promise<string>>()

export function decodeAttachment(attachment: ReportAttachment): Promise<string> {
  let html = decoded.get(attachment.Id)
  if (!html) {
    html = (async () => {
      const base64 = attachmentElement(attachment)?.textContent?.trim() ?? ""
      const compressed = await fetch(`data:application/gzip;base64,${base64}`)
      if (!compressed.body) throw new Error("The attachment is empty.")
      return await new Response(compressed.body.pipeThrough(new DecompressionStream("gzip"))).text()
    })()
    decoded.set(attachment.Id, html)
    html.catch(() => decoded.delete(attachment.Id))
  }
  return html
}

/**
 * Writes an attachment into an iframe of the report. Written this way the frame shares the report's origin, so a
 * page that uses localStorage works from disk too (a blob: or srcdoc frame of a file:// page does not). The frame
 * takes the report's address, so its hash is reset first: the attached page's own router reads it.
 */
export async function writeAttachmentToFrame(attachment: ReportAttachment, frame: HTMLIFrameElement) {
  const html = await decodeAttachment(attachment)
  const frameDocument = frame.contentDocument
  if (!frameDocument) return
  frameDocument.open()
  frame.contentWindow?.history.replaceState(null, "", "#/")
  frameDocument.write(html)
  frameDocument.close()
}

/**
 * Opens an attachment in a new tab. The tab is opened during the click, so that popup blockers allow it, and
 * filled once the content is decompressed.
 *
 * A report opened from disk has an opaque origin, so a blob: URL made from it is opaque too, and a page that uses
 * localStorage (the Zero Trust Assessment report does) fails there. So from disk the page is written into the new
 * tab, which shares the report's file origin; a report served over http(s) opens it from a blob: URL, which keeps
 * the tab's own address and reloads correctly.
 */
export function openReportAttachment(attachment: ReportAttachment) {
  const tab = window.open("", "_blank")
  if (!tab) return
  tab.document.title = attachment.Name
  tab.document.body.textContent = `Opening ${attachment.Name}…`

  decodeAttachment(attachment).then(
    (html) => {
      if (window.location.protocol === "file:") {
        tab.document.open()
        tab.document.write(html)
        tab.document.close()
      } else {
        tab.location.replace(URL.createObjectURL(new Blob([html], { type: "text/html" })))
      }
    },
    (error: unknown) => {
      tab.document.body.textContent = `${attachment.Name} could not be opened: ${error instanceof Error ? error.message : String(error)}`
    }
  )
}
