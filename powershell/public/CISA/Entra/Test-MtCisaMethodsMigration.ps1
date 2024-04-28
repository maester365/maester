<#
.SYNOPSIS
    Checks if migration to Authentication Methods is complete

.DESCRIPTION

    The Authentication Methods Manage Migration feature SHALL be set to Migration Complete.

.EXAMPLE
    Test-MtCisaMethodsMigration

    Returns true if policyMigrationState is migrationComplete
#>

Function Test-MtCisaMethodsMigration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationmethodspolicy" -ApiVersion "v1.0"

    $migrationState = $result.policyMigrationState

    $testResult = $migrationState -eq "migrationComplete"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has completed the migration to Authentication Methods:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has not completed the migration to Authentication Methods."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $migrationState

    return $testResult
}