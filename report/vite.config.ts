import { defineConfig } from "vite"
import preact from "@preact/preset-vite"
import path from "path"
import { viteSingleFile } from "vite-plugin-singlefile"

// https://vitejs.dev/config/
export default defineConfig(({ command }) => ({
  plugins: [preact(), viteSingleFile()],
  // The dev server serves the website's static files, so the report icons load from /report-icons as they do from
  // maester.dev. The build copies nothing: a report loads them from maester.dev.
  publicDir: command === "serve" ? "../website/static" : false,
  resolve: {
    alias: {
      "@": path.resolve(import.meta.dirname, "./src"),
    },
  },
  build: {
    outDir: "dist",
    sourcemap: false,
  },
  server: {
    port: 5173,
    open: true,
  },
}))
