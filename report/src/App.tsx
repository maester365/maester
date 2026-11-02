import { useLocation } from "@/lib/router"
import { ThemeProvider } from "@/components/ThemeProvider"
import { TenantProvider } from "@/context/TenantContext"
import { ReportProvider } from "@/components/report/ReportContext"
import { Shell } from "@/components/report/Shell"

import OverviewPage from "@/pages/report/OverviewPage"
import ActionPlanPage from "@/pages/report/ActionPlanPage"
import TestsPage from "@/pages/report/TestsPage"
import ProductPage from "@/pages/report/ProductPage"
import FrameworkPage from "@/pages/report/FrameworkPage"
import AttackPage from "@/pages/report/AttackPage"
import PackPage from "@/pages/report/PackPage"
import ChangesPage from "@/pages/report/ChangesPage"
import RunPage from "@/pages/report/RunPage"
import TenantsPage from "@/pages/report/TenantsPage"
import AffectedObjectsPage from "@/pages/AffectedObjectsPage"
import SystemPage from "@/pages/SystemPage"
import ConfigPage from "@/pages/ConfigPage"
import ExcelPage from "@/pages/ExcelPage"
import MarkdownPage from "@/pages/MarkdownPage"
import PrintPage from "@/pages/PrintPage"
import ReportAttachmentPage from "@/pages/ReportAttachmentPage"

function decode(value: string) {
  try { return decodeURIComponent(value) } catch { return value }
}

// The page a route names. Any other path is the overview (an old #/<test id> link opens that test over it).
function Page({ pathname }: { pathname: string }) {
  const [, first = "", second = ""] = pathname.split("/")
  switch (first) {
    case "tenants": return <TenantsPage />
    case "plan": return <ActionPlanPage />
    case "tests": return <TestsPage />
    case "product": return <ProductPage productKey={decode(second)} />
    case "framework": return <FrameworkPage frameworkKey={decode(second)} />
    case "attack": return <AttackPage />
    case "pack": return <PackPage packId={decode(second)} />
    case "changes": return <ChangesPage />
    case "run": case "settings": return <RunPage />
    case "system": return <div className="mt-wrap"><SystemPage /></div>
    case "config": return <div className="mt-wrap"><ConfigPage /></div>
    case "affected-objects": return <div className="mt-wrap"><AffectedObjectsPage /></div>
    case "view": return <div className="mt-wrap">{second === "excel" ? <ExcelPage /> : second === "markdown" ? <MarkdownPage /> : <PrintPage />}</div>
    default: return <OverviewPage />
  }
}

function App({ testResults }: { testResults: unknown }) {
  const { pathname } = useLocation()
  // An embedded report fills the main column, without the page padding.
  const isAttachment = pathname.startsWith("/reports/")
  return (
    <ThemeProvider>
      <TenantProvider testResults={testResults}>
        <ReportProvider>
          <Shell flush={isAttachment}>
            {isAttachment ? <ReportAttachmentPage /> : <Page pathname={pathname} />}
          </Shell>
        </ReportProvider>
      </TenantProvider>
    </ThemeProvider>
  )
}

export default App
