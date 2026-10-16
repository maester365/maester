// Display names, areas and icons for the object types in the AffectedObjects. The PowerShell side
// keeps its canonical type names (ConditionalAccessPolicy, or a Graph path for cache reads); this
// file only decides how they read on the Affected objects page.

export interface AffectedObjectTypeInfo {
  name: string
  area: string
  icon: string
}

const knownTypes: Record<string, [name: string, icon: string]> = {
  ConditionalAccessPolicy: ["Conditional Access policy", "conditional-access"],
  User: ["User", "user"],
  Group: ["Group", "group"],
  ServicePrincipal: ["Enterprise application", "enterprise-app"],
  AppRegistration: ["App registration", "app-registration"],
  DirectoryRole: ["Directory role", "directory-role"],
  AccessPackage: ["Access package", "identity-governance"],
  AccessPackageCatalog: ["Access package catalog", "identity-governance"],
  SharingPolicy: ["Sharing policy", "exchange"],
  TransportRule: ["Mail flow rule", "mail-alert"],
}

const systemNames: Record<string, string> = {
  EntraID: "Entra ID",
  ExchangeOnline: "Exchange Online",
  MicrosoftGraph: "Microsoft Graph",
}

// Graph paths read during the run, grouped by the product area they belong to. First match wins,
// so more specific prefixes come first.
const graphAreas: [prefix: string, area: string, icon: string][] = [
  ["deviceManagement", "Intune", "intune"],
  ["deviceAppManagement", "Intune", "intune"],
  ["identityGovernance/roleManagementAlerts", "PIM alerts", "pim"],
  ["identityGovernance", "ID Governance", "identity-governance"],
  ["roleManagement", "Entra roles", "directory-role"],
  ["identity/conditionalAccess", "Conditional Access", "conditional-access"],
  ["policies", "Entra policies", "policy"],
  ["admin", "Microsoft 365 admin center", "tenant"],
  ["directory", "Entra directory", "tenant"],
  ["identityProtection", "ID Protection", "policy"],
  ["reports", "Reports", "tenant"],
]

// Paths whose last segment does not read well on its own.
const graphNames: Record<string, string> = {
  users: "Users",
  groups: "Groups",
  applications: "Applications",
  serviceprincipals: "Enterprise applications",
  servicePrincipals: "Enterprise applications",
  directoryRoles: "Directory roles",
  domains: "Domains",
  organization: "Organization",
  subscribedSkus: "Licenses",
  settings: "Directory settings",
  "policies/authenticationmethodspolicy": "Authentication methods policy",
  "policies/authenticationMethodsPolicy": "Authentication methods policy",
  "policies/crossTenantAccessPolicy/default": "Cross-tenant access default settings",
  "reports/azureADPremiumLicenseInsight": "Entra ID P1/P2 license insight",
  "deviceManagement/depOnboardingSettings": "Apple DEP onboarding settings",
  "deviceManagement/configurationPolicies/settings": "Configuration policy settings",
  "deviceManagement/settings": "Intune tenant settings",
  "deviceManagement/dataProcessorServiceForWindowsFeaturesOnboarding": "Windows data processor onboarding",
  "directory/onPremisesSynchronization": "On-premises sync settings",
  "directory/recommendations": "Entra recommendations",
  "identity/conditionalAccess/policies": "Conditional Access policies",
  "identityProtection/settings/notifications": "Risk notification settings",
}

const guidSegment = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i

// "accessPackageCatalogs" -> "Access package catalogs"
function sentenceCase(value: string) {
  const spaced = value.replace(/([a-z0-9])([A-Z])/g, "$1 $2")
  const words = spaced.split(" ").map((word, index) =>
    index === 0 ? word.charAt(0).toUpperCase() + word.slice(1) : /^[A-Z][a-z]/.test(word) ? word.toLowerCase() : word
  )
  return words.join(" ").replace(/\b(Vpp|Ndes|Pim)\b/gi, (acronym) => acronym.toUpperCase())
}

export function getAffectedObjectTypeInfo(system: string, type: string): AffectedObjectTypeInfo {
  const known = Object.prototype.hasOwnProperty.call(knownTypes, type) ? knownTypes[type] : undefined
  if (known) {
    return { name: known[0], icon: known[1], area: systemNames[system] ?? system }
  }

  const area = graphAreas.find(([prefix]) => type === prefix || type.startsWith(`${prefix}/`))
  const leaf = type.split("/").filter((segment) => !guidSegment.test(segment)).pop() ?? type
  const alert = leaf.match(/_([A-Za-z]+)Alert$/)
  const name = Object.prototype.hasOwnProperty.call(graphNames, type)
    ? graphNames[type]
    : alert
      ? `${sentenceCase(alert[1])} alert`
      : sentenceCase(leaf)

  return {
    name,
    icon: area ? area[2] : "tenant",
    area: area ? area[1] : systemNames[system] ?? system,
  }
}

// Conditional Access policies and users are what most reviews start with, so they lead the default order.
export const affectedObjectTypePriority: Record<string, number> = {
  "Conditional Access policy": 0,
  User: 1,
}
