import { useEffect } from "react"
import { useLocation, useNavigate } from "@/lib/router"
import { WORKSHOP_ATTACHMENT } from "@/lib/zeroTrust"
import { walkItems } from "@/components/report/nav"
import { useNav } from "@/components/report/Sidebar"
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
import PackRoute from "@/pages/report/PackRoute"
import ZeroTrustPage from "@/pages/report/ZeroTrustPage"
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

// A link from before the pack menu (#/zero-trust/<pillar>[/table]) opens the same pillar in the pack's menu. A
// result whose pack has no plan in its menu shows the plan here.
function ZeroTrustRedirect({ pathname }: { pathname: string }) {
  const { nav } = useNav()
  const navigate = useNavigate()
  const [, , pillar = "", mode = ""] = pathname.split("/")
  let base: string | undefined
  for (const h of nav.hubs) for (const { item } of walkItems(h.items)) if (!base && item.page?.view === "plan" && item.page.attachment === WORKSHOP_ATTACHMENT) base = item.page.planPath
  useEffect(() => {
    if (base) navigate(`${base}${pillar ? `/${pillar}` : ""}${mode === "table" ? "#table" : ""}`, { replace: true })
  }, [base]) // eslint-disable-line react-hooks/exhaustive-deps
  return base ? null : <ZeroTrustPage base="/zero-trust" pillarId={decode(pillar)} areaId={mode === "table" ? "" : decode(mode)} />
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
    case "pack": return <PackRoute />
    case "zero-trust": return <ZeroTrustRedirect pathname={pathname} />
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
