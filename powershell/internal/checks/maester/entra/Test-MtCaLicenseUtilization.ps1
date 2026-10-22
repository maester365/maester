function Test-MtCaLicenseUtilization {
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
    [CmdletBinding()]
    param (
        # The type of license to check. Currently supports 'P1' and 'P2'
        [Parameter(Mandatory = $true)]
        [ValidateSet('P1', 'P2')]
        [string]$License
    )
 
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
 
    # When more users use the features than are licensed, say by how much and where to look.
    # The license insight report only returns counts, so the affected users cannot be listed here.
    $riskPolicies = @()
    $overage = $Result.TotalLicensesUtilized - $Result.EntitledLicenseCount
    if ($overage -gt 0) {
        $testResult += "`n`n**$overage** more users are using Entra ID $License features than are licensed for Entra ID $License."
        $testResult += "`n`nTo see license counts and feature usage, open [License usage](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/LicensesMenuBlade/~/LicenseUtilization) in the Microsoft Entra admin center (**Billing** > **Licenses**)."
 
        if ($License -eq 'P2') {
            # Risk-based Conditional Access is the P2 feature the report counts.
            # Measure-Object counts a missing property as 0, where @($null).Count would be 1.
            $riskPolicies = @(Get-MtConditionalAccessPolicy | Where-Object {
                    $_.state -ne 'disabled' -and (
                        ($_.conditions.signInRiskLevels | Measure-Object).Count -gt 0 -or
                        ($_.conditions.userRiskLevels | Measure-Object).Count -gt 0
                    )
                })
            if ($riskPolicies.Count -gt 0) {
                $testResult += "`n`nThese Conditional Access policies use sign-in risk or user risk. Every user they cover needs Entra ID P2:`n`n%TestResult%"
            }
        }
    }
 
    if ($riskPolicies.Count -gt 0) {
        Add-MtTestResultDetail -Description $testDescription -Result $testResult -GraphObjects $riskPolicies -GraphObjectType ConditionalAccess
    } else {
        Add-MtTestResultDetail -Description $testDescription -Result $testResult
    }
 
    return $Result
}