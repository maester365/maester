// The model of the selected tenant's result, which test is open, and the test list's filters, for every view.
// A merged result of several tenants has a model for each; the tenants page compares them.
// A test opens in the sheet when the URL's anchor names it (#/plan#CIS.M365.1.1.1), so a link to it can be
// shared; the 2.x form #/CIS.M365.1.1.1 still works. The list a test was opened from sets the order that the
// sheet's previous and next buttons (and the arrow keys) step through.

import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react"
import { useTenant } from "@/context/TenantContext"
import { useLocation, useNavigate } from "@/lib/router"
import { buildModel, sortTests, type Model } from "@/lib/model"

export interface Explorer {
  q: string
  filters: Record<string, string[]>
  group: string
}

interface ReportContextValue {
  model: Model
  models: Model[]
  multi: boolean
  tenantIndex: number
  /** Switch tenant, then go to a page of that tenant (and open a test when the anchor names one). */
  selectTenant: (index: number, to?: string | { pathname: string; hash?: string }) => void
  openId: string | null
  /** Open a test. `list` is the order of the tests around it, as the view shows them; `replace` keeps the history
   * to one entry while stepping through them. */
  openTest: (id: string, list?: string[], replace?: boolean) => void
  /** The tests the open one was opened among, in order. */
  sequence: string[]
  closeTest: () => void
  explorer: Explorer
  explore: (patch: Partial<Explorer>) => void
  setExplorer: (patch: Partial<Explorer>) => void
  tab: string
  setTab: (tab: string) => void
}

const ReportContext = createContext<ReportContextValue | null>(null)

function decode(value: string) {
  try { return decodeURIComponent(value) } catch { return value }
}

export function ReportProvider({ children }: { children: ReactNode }) {
  const { tenants, selectedIndex, setSelectedIndex } = useTenant()
  const models = useMemo(() => tenants.map(buildModel), [tenants])
  const model = models[selectedIndex] ?? models[0]
  const location = useLocation()
  const navigate = useNavigate()
  const [explorer, setExplorerState] = useState<Explorer>({ q: "", filters: {}, group: "none" })
  const [tab, setTab] = useState("finding")
  const [list, setList] = useState<string[]>([])

  const fromHash = location.hash.length > 1 ? decode(location.hash.slice(1)) : null
  const fromPath = decode(location.pathname.replace(/^\/+|\/+$/g, ""))
  const openId = fromHash && model.byId.has(fromHash) ? fromHash : model.byId.has(fromPath) ? fromPath : null

  const openTest = useCallback((id: string, ids?: string[], replace?: boolean) => {
    if (ids) setList(ids)
    const path = model.byId.has(decode(location.pathname.replace(/^\/+|\/+$/g, ""))) ? "/" : location.pathname
    navigate({ pathname: path, hash: `#${encodeURIComponent(id)}` }, replace ? { replace: true } : undefined)
  }, [location.pathname, model, navigate])
  // A test opened from a link, search or another tenant steps through every test in the usual order.
  const sequence = useMemo(() => (openId && list.includes(openId) ? list : sortTests(model.rows).map((t) => t.Id)), [list, openId, model])
  const closeTest = useCallback(() => {
    const path = model.byId.has(decode(location.pathname.replace(/^\/+|\/+$/g, ""))) ? "/" : location.pathname
    navigate({ pathname: path }, { replace: true })
  }, [location.pathname, model, navigate])
  const selectTenant = useCallback((index: number, to?: string | { pathname: string; hash?: string }) => {
    setSelectedIndex(index)
    if (to) navigate(to)
  }, [navigate, setSelectedIndex])
  const setExplorer = useCallback((patch: Partial<Explorer>) => setExplorerState((e) => ({ ...e, ...patch })), [])
  const explore = useCallback((patch: Partial<Explorer>) => {
    setExplorerState({ q: "", filters: {}, group: "none", ...patch })
    navigate("/tests")
  }, [navigate])

  const value = useMemo(
    () => ({ model, models, multi: models.length > 1, tenantIndex: selectedIndex, selectTenant, openId, openTest, sequence, closeTest, explorer, explore, setExplorer, tab, setTab }),
    [model, models, selectedIndex, selectTenant, openId, openTest, sequence, closeTest, explorer, explore, setExplorer, tab],
  )
  return <ReportContext.Provider value={value}>{children}</ReportContext.Provider>
}

export function useReport() {
  const context = useContext(ReportContext)
  if (!context) throw new Error("useReport must be used within ReportProvider")
  return context
}
