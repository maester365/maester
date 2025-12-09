<#
.SYNOPSIS
    Test Conditional Access License Utilization and return stats on usage for the specific license.

.DESCRIPTION
    Utilization is validated using the insights provided by Microsoft Graph.

    Learn more:
    https://techcommunity.microsoft.com/t5/microsoft-entra-blog/introducing-microsoft-entra-license-utilization-insights/ba-p/3796393

.EXAMPLE
    Test-MtCaLicenseUtilization -License P1

    This example tests the utilization of P1 licenses in the tenant.

    Test-MtCaLicenseUtilization -License P2

    This example tests the utilization of P2 licenses in the tenant.

.LINK
    https://maester.dev/docs/commands/Test-MtCaLicenseUtilization
#>
function Test-MtCaLicenseUtilization {
    [CmdletBinding()]
    param (
        # The type of license to check. Currently supports 'P1' and 'P2'
        [Parameter(Mandatory = $true)]
        [ValidateSet('P1', 'P2')]
        [string]$License
    )

    if (( Get-MtLicenseInformation EntraID ) -eq 'Free') {
        if ($License -eq 'P1') {
            Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        } elseif ($License -eq 'P2') {
            Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        }
        return $null
    }

    try {
        # Get the total number of users in the tenant
        $TotalUserCount = Get-MtTotalEntraIdUserCount

        # Get insights about the premium license utilization
        $EIDPremiumLicenseInsight = Invoke-MtGraphRequest -RelativeUri 'reports/azureADPremiumLicenseInsight' -ApiVersion beta

        # Calculate the total number of users with P1 and P2 licenses
        $entitledP1LicenseCount = $EIDPremiumLicenseInsight.entitledP1LicenseCount + $EIDPremiumLicenseInsight.entitledP2LicenseCount
        $entitledP2LicenseCount = $EIDPremiumLicenseInsight.entitledP2LicenseCount

        $P1FeatureUtilizations = $EIDPremiumLicenseInsight.p1FeatureUtilizations.conditionalAccess.userCount + $EIDPremiumLicenseInsight.p1FeatureUtilizations.conditionalAccessGuestUsers.userCount
        $P2FeatureUtilizations = $EIDPremiumLicenseInsight.p2FeatureUtilizations.riskBasedConditionalAccess.userCount + $EIDPremiumLicenseInsight.p2FeatureUtilizations.riskBasedConditionalAccessGuestUsers.userCount

        Write-Verbose -Message "Total user count: $TotalUserCount & Entitled P1 license count: $entitledP1LicenseCount & Entitled P2 license count: $entitledP2LicenseCount"

        if ($License -eq 'P1') {
            # Calculate the maximum number of users that can be covered by the P1 license
            $MaxP1UserCount = $entitledP1LicenseCount
            if ($entitledP1LicenseCount -ge $TotalUserCount) { $MaxP1UserCount = $TotalUserCount }
            $Result = [PSCustomObject]@{
                EntitledLicenseCount  = $MaxP1UserCount
                TotalLicensesUtilized = $P1FeatureUtilizations
            }
        } elseif ($License -eq 'P2') {
            # Calculate the maximum number of users that can be covered by the P2 license
            $MaxP2UserCount = $entitledP2LicenseCount
            if ($entitledP2LicenseCount -ge $TotalUserCount) { $MaxP2UserCount = $TotalUserCount }
            $Result = [PSCustomObject]@{
                EntitledLicenseCount  = $MaxP2UserCount
                TotalLicensesUtilized = $P2FeatureUtilizations
            }
        }

        $testDescription = "This test checks the utilization of Entra ID $License licenses in the tenant."
        $testResult = "Total users entitled for Entra ID $($License): **$($Result.EntitledLicenseCount)**`n`nTotal $License licenses utilized: **$($Result.TotalLicensesUtilized)**"
        Add-MtTestResultDetail -Description $testDescription -Result $testResult

        return $Result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
