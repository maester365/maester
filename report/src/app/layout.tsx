import { GeistSans } from "geist/font/sans"
import type { Metadata } from "next"
import "./globals.css"

import { Sidebar, SidebarProvider } from "@/components/Sidebar"
import { Breadcrumb } from "@/components/Breadcrumb"
import { ThemeProvider } from "@/components/ThemeProvider"
import { testResults } from "@/lib/testResults"
import { siteConfig } from "./siteConfig"

export const metadata: Metadata = {
  title: siteConfig.name,
  description: siteConfig.description,
  icons: {
    icon: "/favicon.ico",
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${GeistSans.className} min-h-screen overflow-x-hidden bg-gray-50 antialiased selection:bg-orange-100 selection:text-orange-600 dark:bg-black`}
      >
        <ThemeProvider>
          <SidebarProvider>
            <div className="flex h-screen">
              <Sidebar testResults={testResults} />
              <div className="flex flex-1 flex-col overflow-hidden">
                <Breadcrumb />
                <main className="flex-1 overflow-auto">
                  <div className="p-6">{children}</div>
                </main>
              </div>
            </div>
          </SidebarProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
