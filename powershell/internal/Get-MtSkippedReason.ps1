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
        "NotConnectedAzure" { "Not connected to Azure. See [Connecting to Azure](https://maester.dev/docs/installation#optional-modules-and-permissions)" ; break}
        "NotConnectedExchange" { "Not connected to Exchange Online. See [Connecting to Exchange Online](https://maester.dev/docs/installation#optional-modules-and-permissions)"; break}
        "NotDotGovDomain" { "This test is only for federal, executive branch, departments and agencies. To override use [Test-MtCisaDmarcAggregateCisa -Force](https://maester.dev/docs/commands/Test-MtCisaDmarcAggregateCisa)"; break}
        "NotLicensedEntraIDP1" { "This test is for tenants that are licensed for Entra ID P1. See [Entra ID licensing](https://learn.microsoft.com/entra/fundamentals/licensing)"; break}
        "NotLicensedEntraIDP2" { "This test is for tenants that are licensed for Entra ID P2. See [Entra ID licensing](https://learn.microsoft.com/entra/fundamentals/licensing)"; break}
        "NotLicensedEntraIDGovernance" { "This test is for tenants that are licensed for Entra ID Governance. See [Entra ID Governance licensing](https://learn.microsoft.com/entra/fundamentals/licensing#microsoft-entra-id-governance)"; break}
        "NotLicensedEntraWorkloadID" { "This test is for tenants that are licensed for Entra Workload ID. See [Entra Workload ID licensing](https://learn.microsoft.com/entra/workload-id/workload-identities-faqs)"; break}
        "LicensedEntraIDPremium" { "This test is for tenants that are not licensed for any Entra ID Premium license. See [Entra ID licensing](https://learn.microsoft.com/entra/fundamentals/licensing)"; break}
        "NotSupported" { "This test relies on capabilities not currently available (e.g., cmdlets that are not available on all platforms, Resolve-DnsName)"; break}
        default { $SkippedBecause; break}
    }
}
