- **AuditLog.Read.All**
- **DeviceManagementConfiguration.Read.All**
- **DeviceManagementManagedDevices.Read.All**
- **DeviceManagementRBAC.Read.All**
- **DeviceManagementServiceConfig.Read.All**
- **Directory.Read.All**
- **DirectoryRecommendations.Read.All**
- **EntitlementManagement.Read.All**
- **IdentityRiskEvent.Read.All**
- **NetworkAccess.Read.All**
- **OnPremDirectorySynchronization.Read.All**
- **OrgSettings-AppsAndServices.Read.All**
- **OrgSettings-Forms.Read.All**
- **Policy.Read.All**
- **Policy.Read.ConditionalAccess**
- **Reports.Read.All**
- **ReportSettings.Read.All**
- **RoleEligibilitySchedule.Read.Directory**
- **RoleManagement.Read.All**
- **RoleManagementAlert.Read.Directory**
- **SecurityIdentitiesSensors.Read.All**
- **SecurityIdentitiesHealth.Read.All**
- **SharePointTenantSettings.Read.All**
- **ThreatHunting.Read.All**
- **UserAuthenticationMethod.Read.All**

To run preview Agent ID tests, also grant these application permissions:

- **AgentIdentity.Read.All**
- **AgentIdentityBlueprint.Read.All**
- **AgentIdentityBlueprintPrincipal.Read.All**
- **Application.Read.All**

---

### Exchange Online RBAC Roles for Service Principals (App-Only Authentication)

> **Required for ORCA tests and Exchange Online assessments**

When using **certificate-based (app-only) authentication** for Exchange Online or Security & Compliance PowerShell (via `Connect-Maester -Service ExchangeOnline,SecurityCompliance` or direct module connections), the **service principal (Enterprise Application) must be assigned Microsoft Entra roles** to read EOP/MDO configurations.

**Microsoft Graph API permissions alone are NOT sufficient** - Exchange Online uses its own RBAC system.

#### Minimum Required Role: **Security Reader**

| Role | Exchange Online | Security & Compliance | Notes |
|------|-----------------|----------------------|-------|
| **Security Reader** | ✔ | ✔ | **Minimum for ORCA tests** - read-only access to security configs |
| Global Reader | ✔ | ✔ | Read-only access to all admin centers |
| Exchange Administrator | ✔ | | Full Exchange management |
| Compliance Administrator | ✔ | ✔ | Compliance & security configs |
| Security Administrator | ✔ | ✔ | Security configs + some management |
| Exchange Recipient Administrator | ✔ | | Recipient management |
| Helpdesk Administrator | ✔ | | Limited recipient management |
| Global Administrator | ✔ | ✔ | Full access (not recommended for automation) |

#### To Assign the Role

1. Go to **Microsoft Entra admin center** → **Identity** → **Roles & admins**
2. Search for **Security Reader** (or desired role)
3. Select **Add assignments**
4. Search for and select your **Enterprise Application** (service principal name)
5. Select **Add**

#### Why This Matters

Without the Security Reader role (or equivalent):
- `Connect-ExchangeOnline` / `Connect-IPPSSession` **succeeds** (authentication works)
- But EXO cmdlets (`Get-AcceptedDomain`, `Get-SafeLinksPolicy`, `Get-AntiPhishPolicy`, etc.) return **empty results**
- ORCA tests evaluate against empty data → **report false failures**

See [Connect-Maester Advanced: Certificate-based authentication](/docs/connect-maester/connect-maester-advanced#required-exchange-online-rbac-roles-for-service-principals) for full details.
