function Test-MtCisEnsureGuestAccessRestrictedCompliance {
    <#
    .SYNOPSIS
    Checks if guest user access is restricted.

    .DESCRIPTION
    Guest user access should be restricted to only necessary resources.
        CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisEnsureGuestAccessRestrictedCompliance
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

    try {
        Write-Verbose 'Getting settings...'
        $settings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/authorizationPolicy' -DisableCache

        $testResult = $settings.guestUserRoleId -eq "10dae51f-b6af-4016-8d66-8c2a99b929b3" -or $settings.guestUserRoleId -eq "2af84b1e-32c8-42b7-82bc-daa82404023b"
        return $testResult
    }
    catch {
        return $null
    }

}
