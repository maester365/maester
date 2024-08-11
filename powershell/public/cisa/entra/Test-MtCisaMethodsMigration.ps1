<#
.SYNOPSIS
    Checks if migration to Authentication Methods is complete

.DESCRIPTION
    The Authentication Methods Manage Migration feature SHALL be set to Migration Complete.

.EXAMPLE
    Test-MtCisaMethodsMigration

    Returns true if policyMigrationState is migrationComplete

.LINK
    https://maester.dev/docs/commands/Test-MtCisaMethodsMigration
#>
function Test-MtCisaMethodsMigration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    if($EntraIDPlan -eq "Free"){
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    #4/28/2024 - Select OData query option not supported
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationmethodspolicy" -ApiVersion "v1.0"

    $migrationState = $result.policyMigrationState

    $testResult = $migrationState -eq "migrationComplete"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has completed the migration to Authentication Methods."
    } else {
        $testResultMarkdown = "Your tenant has not completed the migration to Authentication Methods."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}