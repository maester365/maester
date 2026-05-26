function Test-MtCisaMethodsMigrationCompliance {
    <#
    .SYNOPSIS
    Checks if migration to Authentication Methods is complete

    .DESCRIPTION
    The Authentication Methods Manage Migration feature SHALL be set to Migration Complete.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaMethodsMigrationCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    if($EntraIDPlan -eq "Free"){
        return $null
    }

    #4/28/2024 - Select OData query option not supported
    $result = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/authenticationmethodspolicy' -ApiVersion "v1.0"

    $migrationState = $result.policyMigrationState

    $testResult = $migrationState -eq "migrationComplete" -or $null -eq $migrationState # Can be 'null' in new tenants that never had legacy settings to migrate from.
    return $testResult

}
