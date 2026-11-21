// The report data and attachments are embedded as gzip-compressed text, Base64-encoded, in script elements.

/** The text of gzip-compressed, Base64-encoded content. */
export async function decodeGzipBase64(base64: string): Promise<string> {
  const binary = atob(base64.replace(/\s+/g, ""))
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"))
  return await new Response(stream).text()
}
