function Test-MtCaLicenseUtilization {
    [CmdletBinding()]
    param (
        [string]$License
    )

    # Get the total number of users in the tenant
    $TotalUserCount = Get-MtTotalEntraIdUserCount

    # Get insights about the premium license utilization
    $EIDPremiumLicenseInsight = Invoke-MtGraphRequest -RelativeUri "reports/azureADPremiumLicenseInsight" -ApiVersion beta

    # Calculate the total number of users with P1 and P2 licenses
    $entitledP1LicenseCount = $EIDPremiumLicenseInsight.entitledP1LicenseCount + $EIDPremiumLicenseInsight.entitledP2LicenseCount
    $entitledP2LicenseCount = $EIDPremiumLicenseInsight.entitledP2LicenseCount

    $P1FeatureUtilizations = $EIDPremiumLicenseInsight.p1FeatureUtilizations.conditionalAccess.userCount + $EIDPremiumLicenseInsight.p1FeatureUtilizations.conditionalAccessGuestUsers.userCount
    $P2FeatureUtilizations = $EIDPremiumLicenseInsight.p2FeatureUtilizations.riskBasedConditionalAccess.userCount + $EIDPremiumLicenseInsight.p2FeatureUtilizations.riskBasedConditionalAccessGuestUsers.userCount

    if ($License -eq "P1") {
        # Calculate the maximum number of users that can be covered by the P1 license
        $MaxP1UserCount = $entitledP1LicenseCount -ge $TotalUserCount ? $TotalUserCount : $entitledP1LicenseCount
        $Result = [PSCustomObject]@{
            EntitledLicenseCount  = $MaxP1UserCount
            TotalLicensesUtilized = $P1FeatureUtilizations
        }
    } elseif ($License -eq "P2") {
        # Calculate the maximum number of users that can be covered by the P2 license
        $MaxP2UserCount = $entitledP2LicenseCount -ge $TotalUserCount ? $TotalUserCount : $entitledP2LicenseCount
        $Result = [PSCustomObject]@{
            EntitledLicenseCount  = $MaxP2UserCount
            TotalLicensesUtilized = $P2FeatureUtilizations
        }
    } else {
        Write-Warning "Invalid license type. Please specify either 'P1' or 'P2'"
        $Result = $false
    }
    Return $Result
}