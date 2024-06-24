﻿<#
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
        "NotLicensedEntraIDP1" { "This test is for tenants that are licensed for Entra ID P1. See [Entra ID licensing](https://learn.microsoft.com/entra/fundamentals/licensing)"; break}
        "NotLicensedEntraIDP2" { "This test is for tenants that are licensed for Entra ID P2. See [Entra ID licensing](https://learn.microsoft.com/entra/fundamentals/licensing)"; break}
        "NotLicensedEntraIDGovernance" { "This test is for tenants that are licensed for Entra ID Governance. See [Entra ID Governance licensing](https://learn.microsoft.com/entra/fundamentals/licensing#microsoft-entra-id-governance)"; break}
        "NotLicensedEntraWorkloadID" { "This test is for tenants that are licensed for Entra Workload ID. See [Entra Workload ID licensing](https://learn.microsoft.com/entra/workload-id/workload-identities-faqs)"; break}
        "SecurityDefaultDisabled" { "Security defaults are disabled. See [Security defaults](https://learn.microsoft.com/en-us/entra/fundamentals/security-defaults)"; break}
        default { $SkippedBecause; break}
    }
}