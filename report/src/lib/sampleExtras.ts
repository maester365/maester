// Dev only: what a real run adds that the sample result lacks. Earlier runs' counts (Previous.History) for the
// trend, and AffectedObjects for "What Maester checked". Both are made from the result itself, the same on every load.

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Raw = Record<string, any>

// The Zero Trust Assessment pack's own menu and guide, so the sample shows the pack as a real run does.
const ztaFiles = import.meta.glob<Raw>(["../../../packs/zero-trust-assessment/maester-pack.json", "../../../packs/zero-trust-assessment/maester-pack.guide.json"], { eager: true, import: "default" })
const ztaManifest = Object.entries(ztaFiles).find(([k]) => k.endsWith("maester-pack.json"))?.[1]
const ztaGuide = Object.entries(ztaFiles).find(([k]) => k.endsWith("guide.json"))?.[1]

const USERS = ["Adele Vance", "Alex Wilber", "Bagul Atayewa", "Bob Leaf", "Damien Bowden", "Diego Siciliani", "Emergency Access", "Gael Colas", "Isaiah Langer", "Joshua Fernando", "Lee Gu", "Megan Bowen", "Miriam Graham", "Nestor Wilke", "Patti Fernandez", "Tyler Chan"]
const POLICIES = ["Require MFA for admins", "Block legacy authentication", "Require MFA for all users", "Require compliant device for admins", "Block sign-in from risky locations", "Require password change for high-risk users", "Sign-in frequency for admins", "Block device code flow"]
const GROUPS = ["All Staff", "Break glass accounts", "Finance", "Helpdesk", "Privileged access reviewers"]
const APPS = ["Contoso HR", "Expense Tracker", "Graph Explorer", "Maester", "Microsoft Graph Command Line Tools", "Payroll Connector", "Salesforce", "ServiceNow", "Slack", "Zoom"]
const REGISTRATIONS = ["contoso-api", "contoso-web", "invoice-bot", "legacy-sync", "reporting-dashboard", "test-app"]
const ROLES = ["Global Administrator", "Privileged Role Administrator", "Security Administrator", "Exchange Administrator", "Application Administrator", "User Administrator"]
const RULES = ["External sender warning", "Block auto-forward to external"]

function ids(result: Raw, product: string, features: string[]) {
  return (result.Tests as Raw[]).filter((t) => t.Product === product && features.includes(t.Feature)).map((t) => String(t.Id))
}

export function withSampleExtras(result: Raw, seed = 0): Raw {
  if (!Array.isArray(result?.Tests)) return result
  const pick = (list: string[], i: number) => list.filter((_, j) => (j + i + seed) % 3 !== 0).slice(0, 4)
  const objects: Raw[] = []
  const add = (type: string, system: string, names: string[], tests: string[]) => names.forEach((n, i) => objects.push({ System: system, Type: type, Id: `${type}-${i}`, DisplayName: n, Tests: pick(tests, i), Referenced: true }))
  add("User", "EntraID", USERS, ids(result, "entra", ["roles", "privileged-identity-management"]).concat(ids(result, "microsoft-365", ["administrative-accounts"])))
  add("ConditionalAccessPolicy", "EntraID", POLICIES, ids(result, "entra", ["conditional-access"]))
  add("Group", "EntraID", GROUPS, ids(result, "entra", ["groups", "identity-governance"]))
  add("ServicePrincipal", "EntraID", APPS, ids(result, "entra", ["applications", "app-consent"]))
  add("AppRegistration", "EntraID", REGISTRATIONS, ids(result, "entra", ["applications", "app-consent"]))
  add("DirectoryRole", "EntraID", ROLES, ids(result, "entra", ["roles", "privileged-identity-management"]))
  add("TransportRule", "ExchangeOnline", RULES, ids(result, "exchange", ["mail-flow"]))
  for (const path of ["users", "groups", "servicePrincipals", "applications", "directoryRoles", "domains", "organization", "subscribedSkus", "policies/authorizationPolicy", "identity/conditionalAccess/policies", "policies/authenticationMethodsPolicy", "roleManagement/directory/roleAssignments"]) {
    objects.push({ System: "MicrosoftGraph", Type: path, Id: path, DisplayName: path, Tests: [], Referenced: false })
  }

  // Weekly runs before the previous one, with a few more failures the further back they go.
  const previous = result.Previous
  let withHistory = previous
  if (previous && !previous.History) {
    // The newest entry is the previous run itself; the rest go back a week at a time.
    const before = Object.values(previous.Results || {}) as string[]
    const count = (r: string) => before.filter((v) => v === r).length
    const history = Array.from({ length: 9 }, (_, i) => {
      const at = new Date(previous.ExecutedAt)
      at.setDate(at.getDate() - 7 * i)
      const drift = i === 0 ? 0 : Math.round(i * (2.6 + (seed % 3)) + ((i * 7 + seed) % 5))
      return { ExecutedAt: at.toISOString(), Total: before.length, Passed: Math.max(0, count("Passed") - drift), Failed: count("Failed") + drift, Investigate: count("Investigate"), Error: count("Error"), Skipped: count("Skipped"), NotRun: count("NotRun") }
    })
    withHistory = { ...previous, History: history }
  }
  // A run with Zero Trust Assessment results gets the Zero Trust plan, built from the pack's files (sampleZeroTrust.ts).
  const hasZta = result.Tests.some((t: Raw) => typeof t?.Id === "string" && t.Id.startsWith("ZTA."))
  const attachments = hasZta && !(result.Attachments || []).some((a: Raw) => a?.Name === "zero-trust-workshop")
    ? [...(result.Attachments || []), { Id: "dev:zero-trust-workshop", Name: "zero-trust-workshop", ContentType: "application/json" }]
    : result.Attachments
  const packs = hasZta && ztaManifest
    ? (() => {
        const list: Raw[] = Array.isArray(result.Packs) ? [...result.Packs] : []
        const i = list.findIndex((p) => p?.Id === ztaManifest.Id)
        const extra = { Logo: ztaManifest.Report?.Logo ?? null, Navigation: JSON.stringify(ztaManifest.Report?.Navigation ?? null), Guide: JSON.stringify(ztaGuide ?? null) }
        if (i >= 0) list[i] = { ...extra, ...list[i] }
        else list.push({ Id: ztaManifest.Id, Code: ztaManifest.Code, Name: ztaManifest.Name, Description: ztaManifest.Description, Version: ztaManifest.Version, Publisher: ztaManifest.Publisher, BuiltIn: true, Homepage: ztaManifest.Homepage, Status: "Ready", ...extra })
        return list
      })()
    : result.Packs
  return { ...result, AffectedObjects: result.AffectedObjects ?? objects, Previous: withHistory, ...(attachments ? { Attachments: attachments } : {}), ...(packs ? { Packs: packs } : {}) }
}
