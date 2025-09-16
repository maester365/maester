<#
.SYNOPSIS
    Returns the description for why a test was skipped.
#>
function Get-MtSkippedReason {
    param(
        # The reason for skipping
        [string] $SkippedBecause
    )

    switch($SkippedBecause){
        "NotConnectedAzure" { "Not connected to Azure. See [Connecting to Azure](https://maester.dev/docs/connect-maester/#connect-to-azure-exchange-online-and-teams)"; break}
        "NotConnectedExchange" { "Not connected to Exchange Online. See [Connecting to Exchange Online](https://maester.dev/docs/connect-maester/#connect-to-azure-exchange-online-and-teams)"; break}
        "NotConnectedSecurityCompliance" { "Not connected to Security & Compliance. See [Connecting to Security & Compliance](https://maester.dev/docs/connect-maester/#connect-to-azure-exchange-online-and-teams)"; break}
        "NotConnectedTeams" { "Not connected to Teams. See [Connecting to Teams](https://maester.dev/docs/connect-maester/#connect-to-azure-exchange-online-and-teams)"; break}
        "NotConnectedGraph" { "Not connected to Graph. See [Connect-Maester](https://maester.dev/docs/commands/Connect-Maester#examples)"; break}
        "NotDotGovDomain" { "This test is only for federal, executive branch, departments and agencies. To override use [Test-MtCisaDmarcAggregateCisa -Force](https://maester.dev/docs/commands/Test-MtCisaDmarcAggregateCisa)"; break}
        "NotLicensedEntraIDP1" { "This test is for tenants that are licensed for Entra ID P1. See [Entra ID licensing](https://learn.microsoft.com/entra/fundamentals/licensing)"; break}
        "NotLicensedEntraIDP2" { "This test is for tenants that are licensed for Entra ID P2. See [Entra ID licensing](https://learn.microsoft.com/entra/fundamentals/licensing)"; break}
        "NotLicensedEntraIDGovernance" { "This test is for tenants that are licensed for Entra ID Governance. See [Entra ID Governance licensing](https://learn.microsoft.com/entra/fundamentals/licensing#microsoft-entra-id-governance)"; break}
        "NotLicensedEntraWorkloadID" { "This test is for tenants that are licensed for Entra Workload ID. See [Entra Workload ID licensing](https://learn.microsoft.com/entra/workload-id/workload-identities-faqs)"; break}
        "NotLicensedEop" { "This test is for tenants that are licensed for Exchange Online Protection. See [Exchange Online Protection service description](https://learn.microsoft.com/en-us/office365/servicedescriptions/exchange-online-protection-service-description/exchange-online-protection-service-description)"; break}
        "NotLicensedExoDlp" { "This test is for tenants that are licensed for Exchange Online DLP. See [Microsoft Purview Data Loss Prevention: Data Loss Prevention (DLP) for Exchange Online, SharePoint Online, and OneDrive for Business](https://learn.microsoft.com/en-us/office365/servicedescriptions/microsoft-365-service-descriptions/microsoft-365-tenantlevel-services-licensing-guidance/microsoft-365-security-compliance-licensing-guidance#which-licenses-provide-the-rights-for-a-user-to-benefit-from-the-service-7)"; break}
        "NotLicensedMdo" { "This test is for tenants that are licensed for Defender for Office 365 Plan 2. See [Microsoft Defender for Office 365 service description](https://learn.microsoft.com/en-us/office365/servicedescriptions/office-365-advanced-threat-protection-service-description)"; break}
        "NotLicensedMdoP2" { "This test is for tenants that are licensed for Defender for Office 365 Plan 2. See [Microsoft Defender for Office 365 service description](https://learn.microsoft.com/en-us/office365/servicedescriptions/office-365-advanced-threat-protection-service-description)"; break}
        "NotLicensedMdoP1" { "This test is for tenants that are licensed for Defender for Office 365 Plan 1. See [Microsoft Defender for Office 365 service description](https://learn.microsoft.com/en-us/office365/servicedescriptions/office-365-advanced-threat-protection-service-description)"; break}
        "NotLicensedAdvAudit" { "This test is for tenants that are licensed for Advanced Audit. See [Learn about auditing solutions in Microsoft Purview](https://learn.microsoft.com/en-us/purview/audit-solutions-overview#licensing-requirements)"; break}
        "LicensedEntraIDPremium" { "This test is for tenants that are not licensed for any Entra ID Premium license. See [Entra ID licensing](https://learn.microsoft.com/entra/fundamentals/licensing)"; break}
        "NotSupported" { "This test relies on capabilities not currently available (e.g., cmdlets that are not available on all platforms, Resolve-DnsName)"; break}
        "NotSupportedAppPermission" { "This test relies on Graph APIs that don't support application permissions. Re-run Maester with a user signed in to view the results for this test."; break}
        "LimitedPermissions" { "This test relies on privileged (i.e., ReadWrite) permissions."; break}
        "NotLicensedDefenderXDR" { "This test is for tenants that are licensed for Microsoft Defender XDR. See [Microsoft Defender XDR prerequisites](https://learn.microsoft.com/en-us/defender-xdr/prerequisites#licensing-requirements)"; break}
        "Error" { $SkippedBecause; break}
        default { $SkippedBecause; break}
    }
}
