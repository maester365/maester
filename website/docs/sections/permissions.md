---
# A partial that guides import; also served as a page (noindex) for links to it.
title: Microsoft Graph permissions Maester uses
---

- **AccessReview.Read.All**
- **AuditLog.Read.All**
- **DeviceManagementApps.Read.All**
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

To run preview tests, also grant these application permissions:

- **AgentIdentity.Read.All**
- **AgentIdentityBlueprint.Read.All**
- **AgentIdentityBlueprintPrincipal.Read.All**
- **Application.Read.All**
- **IdentityRiskyUser.Read.All**

To run the preview Tenant Configuration Management drift test (MT.1254), also grant this application permission:

- **ConfigurationMonitoring.Read.All**

To run the preview Tenant Governance and GDAP relationship test (MT.1258), also grant these application permissions:

- **RemoteTenantGroups.Read.All**
- **TenantGovernance-Relationship.Read.All**

Optional MT.1258 report enrichment uses **CrossTenantInformation.ReadBasic.All** for tenant names and
**TenantGovernance-RelatedTenant.Read.All** for inbound admin-app user/application metrics. Discovery is enabled by
default, skipped without Microsoft Entra ID Governance licensing, and can be disabled with
`IncludeTenantDiscovery = false`. MT.1254 and MT.1258 run only in the worldwide (Global) cloud, which Commercial and GCC tenants use.
Failures reading discovery, cross-tenant service-provider information, role details or partner metadata do not
affect the GDAP/Tenant Governance verdict.
