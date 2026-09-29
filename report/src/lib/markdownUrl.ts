import { defaultUrlTransform } from "react-markdown"

// Test results can contain tenant-controlled text (app, user and policy names). If such a value
// isn't escaped, markdown like ![x](https://attacker.example/p.png) would make the report fetch a
// remote image whenever it's opened, telling the attacker who opened it and when. Only allow
// images that are embedded in the report or hosted by Maester.
const allowedImage = /^(data:image\/(png|gif|jpe?g|webp);base64,|https:\/\/maester\.dev\/)/i

export function markdownUrlTransform(url: string, key: string): string {
  if (key === "src") {
    return allowedImage.test(url) ? url : ""
  }
  // Links keep react-markdown's default policy (http, https, mailto, relative; no javascript:).
  return defaultUrlTransform(url)
}
