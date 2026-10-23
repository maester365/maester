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

// The attached page is another tool's HTML. It runs in a sandboxed frame without allow-same-origin, so its
// scripts run in an opaque origin and cannot reach the Maester report, its data or its storage.
export const attachmentSandbox = "allow-scripts allow-popups allow-popups-to-escape-sandbox allow-downloads"

function escapeHtml(text: string) {
  return text.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// Run first in the attached page, so that a page written for its own origin still works in the sandbox:
// an opaque origin has no web storage, so a page that reads localStorage unguarded (the Zero Trust Assessment
// report does) gets storage kept in memory instead; and a srcdoc page's address, about:srcdoc, is no base for
// new URL(path, location.href), which a router (React Router, in that report) calls.
const sandboxShim =
  "<script>(function(){var B=URL;window.URL=class extends B{constructor(u,b){if(b!==undefined&&String(b).indexOf('about:')===0)" +
  "{super(u,'http://localhost/')}else{super(u,b)}}};" +
  "function memory(){var d=new Map();return{get length(){return d.size}," +
  "key:function(i){return Array.from(d.keys())[i]??null},getItem:function(k){k=String(k);return d.has(k)?d.get(k):null}," +
  "setItem:function(k,v){d.set(String(k),String(v))},removeItem:function(k){d.delete(String(k))},clear:function(){d.clear()}}}" +
  "['localStorage','sessionStorage'].forEach(function(n){try{window[n]}catch(e){Object.defineProperty(window,n,{value:memory(),configurable:true})}})})()</script>"

/** The attached page with the sandbox script placed after its doctype, so the page keeps its rendering mode. */
function sandboxedDocument(html: string) {
  return html.replace(/^(\uFEFF?\s*<!doctype[^>]*>)?/i, (doctype) => doctype + sandboxShim)
}

/** Shows an attachment in a sandboxed iframe of the report. */
export async function writeAttachmentToFrame(attachment: ReportAttachment, frame: HTMLIFrameElement) {
  const html = await decodeAttachment(attachment)
  frame.setAttribute("sandbox", attachmentSandbox)
  frame.srcdoc = sandboxedDocument(html)
}

/**
 * Opens an attachment in a new tab. The tab is opened during the click, so that popup blockers allow it, and
 * filled once the content is decompressed. It loads a blob: page that holds the attachment in the same sandboxed
 * frame as the report does, since a blob: URL shares the report's origin.
 */
export function openReportAttachment(attachment: ReportAttachment) {
  const tab = window.open("", "_blank")
  if (!tab) return
  tab.opener = null
  tab.document.title = attachment.Name
  tab.document.body.textContent = `Opening ${attachment.Name}…`

  decodeAttachment(attachment).then(
    (html) => {
      const page =
        `<!doctype html><html><head><meta charset="utf-8"><title>${escapeHtml(attachment.Name)}</title>` +
        `<style>html,body,iframe{margin:0;width:100%;height:100%;border:0;display:block}</style></head>` +
        `<body><iframe sandbox="${attachmentSandbox}" srcdoc="${escapeHtml(sandboxedDocument(html))}"></iframe></body></html>`
      tab.location.replace(URL.createObjectURL(new Blob([page], { type: "text/html" })))
    },
    (error: unknown) => {
      tab.document.body.textContent = `${attachment.Name} could not be opened: ${error instanceof Error ? error.message : String(error)}`
    }
  )
}
