import { Routes, Route, useLocation } from "react-router-dom"
import { useEffect, useRef } from "react"
import { Sidebar, SidebarProvider } from "@/components/Sidebar"
import { Breadcrumb } from "@/components/Breadcrumb"
import { ThemeProvider } from "@/components/ThemeProvider"
import { testResults } from "@/lib/testResults"

// Import pages
import HomePage from "@/pages/HomePage"
import SettingsPage from "@/pages/SettingsPage"
import SystemPage from "@/pages/SystemPage"
import ConfigPage from "@/pages/ConfigPage"
import ExcelPage from "@/pages/ExcelPage"
import MarkdownPage from "@/pages/MarkdownPage"
import PrintPage from "@/pages/PrintPage"

// Component to scroll to top on route change
function ScrollToTop({ mainRef }: { mainRef: React.RefObject<HTMLElement | null> }) {
  const { pathname } = useLocation()

  useEffect(() => {
    if (mainRef.current) {
      mainRef.current.scrollTo(0, 0)
    }
  }, [pathname, mainRef])

  return null
}

function App() {
  const mainRef = useRef<HTMLElement>(null)

  return (
    <ThemeProvider>
      <SidebarProvider>
        <div className="flex h-screen font-sans min-h-screen overflow-x-hidden bg-gray-50 antialiased selection:bg-orange-100 selection:text-orange-600 dark:bg-black">
          <Sidebar testResults={testResults} />
          <div className="flex flex-1 flex-col overflow-hidden">
            <Breadcrumb testResults={testResults} />
            <main ref={mainRef} className="flex-1 overflow-auto">
              <ScrollToTop mainRef={mainRef} />
              <div className="p-6">
                <Routes>
                  <Route path="/" element={<HomePage />} />
                  <Route path="/settings" element={<SettingsPage />} />
                  <Route path="/system" element={<SystemPage />} />
                  <Route path="/config" element={<ConfigPage testResults={testResults} />} />
                  <Route path="/view/excel" element={<ExcelPage />} />
                  <Route path="/view/markdown" element={<MarkdownPage />} />
                  <Route path="/view/print" element={<PrintPage />} />
                </Routes>
              </div>
            </main>
          </div>
        </div>
      </SidebarProvider>
    </ThemeProvider>
  )
}

export default App
