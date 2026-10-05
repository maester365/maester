import { useLocation } from "@/lib/router"
import { useEffect, useRef } from "react"
import { Sidebar, SidebarProvider } from "@/components/Sidebar"
import { Breadcrumb } from "@/components/Breadcrumb"
import { ThemeProvider } from "@/components/ThemeProvider"
import { TenantProvider } from "@/context/TenantContext"

// Import pages
import HomePage from "@/pages/HomePage"
import AffectedObjectsPage from "@/pages/AffectedObjectsPage"
import SettingsPage from "@/pages/SettingsPage"
import SystemPage from "@/pages/SystemPage"
import ConfigPage from "@/pages/ConfigPage"
import ExcelPage from "@/pages/ExcelPage"
import MarkdownPage from "@/pages/MarkdownPage"
import PrintPage from "@/pages/PrintPage"
import { reportMainElementId } from "@/lib/reportLinks"

// Component to scroll to top on route change.
// Skipped when a hash is present because the deep-link scroll will position
// the viewport to the correct row instead.
function ScrollToTop({ mainRef }: { mainRef: React.RefObject<HTMLElement | null> }) {
  const { pathname, hash } = useLocation()

  useEffect(() => {
    if (hash) return
    if (mainRef.current) {
      mainRef.current.scrollTo(0, 0)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname])

  return null
}

function App({ testResults }: { testResults: unknown }) {
  const mainRef = useRef<HTMLElement>(null)
  const { pathname } = useLocation()
  const page = pathname === "/affected-objects" ? <AffectedObjectsPage />
    : pathname === "/settings" ? <SettingsPage />
      : pathname === "/system" ? <SystemPage />
        : pathname === "/config" ? <ConfigPage />
          : pathname === "/view/excel" ? <ExcelPage />
            : pathname === "/view/markdown" ? <MarkdownPage />
              : pathname === "/view/print" ? <PrintPage />
                : <HomePage />

  return (
    <ThemeProvider>
      <TenantProvider testResults={testResults}>
        <SidebarProvider>
          <div className="flex h-screen font-sans min-h-screen overflow-x-hidden bg-gray-50 antialiased selection:bg-orange-100 selection:text-orange-600 dark:bg-black">
            <Sidebar />
            <div className="flex flex-1 flex-col overflow-hidden">
              <Breadcrumb />
              <main id={reportMainElementId} ref={mainRef} className="flex-1 overflow-auto">
                <ScrollToTop mainRef={mainRef} />
                <div className="p-6">
                  {page}
                </div>
              </main>
            </div>
          </div>
        </SidebarProvider>
      </TenantProvider>
    </ThemeProvider>
  )
}

export default App
