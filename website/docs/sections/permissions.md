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

To run preview tests of features that only the worldwide (Global) cloud offers, also grant these application
permissions. Commercial and GCC tenants use the Global cloud.

- **ConfigurationMonitoring.Read.All**
- **CrossTenantInformation.ReadBasic.All**
- **RemoteTenantGroups.Read.All**
- **TenantGovernance-RelatedTenant.Read.All**
- **TenantGovernance-Relationship.Read.All**

`Get-MtGraphScope -IncludePreview` includes them only for `-Environment Global` (the default), and
`Connect-Maester -Environment` passes the cloud on. A connection to a national cloud (US Government, US Government
DoD or China) does not request them, because Microsoft Graph does not offer these APIs there and the sign-in would
fail on a permission the cloud does not publish.
