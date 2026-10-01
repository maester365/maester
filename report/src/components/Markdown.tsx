import DOMPurify from "dompurify"
import { Marked } from "marked"
import { useMemo, type HTMLAttributes } from "react"

const escapeHtml = (text: string) =>
  text.replace(/[&<>"']/g, (char) => `&#${char.charCodeAt(0)};`)

// Raw HTML in test results is shown as text, as react-markdown did. Tenant-controlled names can
// end up in the markdown, so rendering it would let them inject markup such as tracking images.
const markdown = new Marked({
  gfm: true,
  async: false,
  renderer: { html: ({ text }) => escapeHtml(text) },
})

// Only allow images that are embedded in the report or hosted by Maester, so a name that slips
// through unescaped as ![x](https://attacker.example/p.png) can't make the report fetch it.
const allowedImage = /^(data:image\/(png|gif|jpe?g|webp);base64,|https:\/\/maester\.dev\/)/i

DOMPurify.addHook("afterSanitizeAttributes", (node) => {
  if (node.tagName === "IMG" && !allowedImage.test(node.getAttribute("src") ?? "")) {
    node.removeAttribute("src")
  }
})

export function Markdown({ children, ...props }: { children?: string | null } & Omit<HTMLAttributes<HTMLDivElement>, "children">) {
  const html = useMemo(
    () => {
      const rendered = markdown
        .parse(children ?? "", { async: false })
        .replace(/<(th|td) align="(left|center|right)"/g, '<$1 style="text-align: $2;"')
      return DOMPurify.sanitize(rendered)
    },
    [children],
  )

  return <div {...props} dangerouslySetInnerHTML={{ __html: html }} />
}
