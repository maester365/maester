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
        "NotLicensed" { "Not licensed for the required workload"; break}
        "NotLicensedEntraIDP1" { "Not licensed for Entra ID P1"; break}
        "NotLicensedEntraIDP2" { "Not licensed for Entra ID P2"; break}
        "NotLicensedEntraIDGovernance" { "Not licensed for Entra ID Governance"; break}
        "NotLicensedEntraWorkloadID" { "Not licensed for Entra Workload ID"; break}
        default { $SkippedBecause; break}
    }
}