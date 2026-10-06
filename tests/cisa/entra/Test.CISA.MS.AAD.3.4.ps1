function Test-MtCisaMethodsMigration {
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
    [MaesterTest(
        Id = 'CISA.MS.AAD.3.4',
        Title = 'The Authentication Methods Manage Migration feature SHALL be set to Migration Complete.',
        Severity = 'High',
        Category = 'CISA',
        Tag = ('Entra ID P1', 'MS.AAD', 'MS.AAD.3.4'),
        Service = 'Graph',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    if($EntraIDPlan -eq "Free"){
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    #4/28/2024 - Select OData query option not supported
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationmethodspolicy" -ApiVersion "v1.0"

    $migrationState = $result.policyMigrationState

    $testResult = $migrationState -eq "migrationComplete" -or $null -eq $migrationState # Can be 'null' in new tenants that never had legacy settings to migrate from.

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has completed the migration to Authentication Methods."
    } else {
        $testResultMarkdown = "Your tenant has not completed the migration to Authentication Methods."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
