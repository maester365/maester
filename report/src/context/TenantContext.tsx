import { createContext, useContext, useState, useMemo } from "react"

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type TenantResult = Record<string, any>

interface TenantContextType {
  tenants: TenantResult[]
  selectedIndex: number
  selectedTenant: TenantResult
  setSelectedIndex: (index: number) => void
}

const TenantContext = createContext<TenantContextType | null>(null)

export function useTenant(): TenantContextType {
  const ctx = useContext(TenantContext)
  if (!ctx) {
    throw new Error("useTenant must be used within a TenantProvider")
  }
  return ctx
}

interface TenantProviderProps {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  testResults: any
  children: React.ReactNode
}

/**
 * Normalizes test results into a multi-tenant array.
 * Supports both legacy single-tenant format and new multi-tenant format.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function normalizeTenants(testResults: any): TenantResult[] {
  if (Array.isArray(testResults?.Tenants) && testResults.Tenants.length > 0) {
    return testResults.Tenants
  }
  // Legacy single-tenant format — wrap in array
  return [testResults]
}

export function TenantProvider({ testResults, children }: TenantProviderProps) {
  const tenants = useMemo(() => normalizeTenants(testResults), [testResults])
  const [selectedIndex, setSelectedIndex] = useState(0)
  const selectedTenant = tenants[selectedIndex] ?? tenants[0]

  const value = useMemo(
    () => ({ tenants, selectedIndex, selectedTenant, setSelectedIndex }),
    [tenants, selectedIndex, selectedTenant]
  )

  return (
    <TenantContext.Provider value={value}>
      {children}
    </TenantContext.Provider>
  )
}
