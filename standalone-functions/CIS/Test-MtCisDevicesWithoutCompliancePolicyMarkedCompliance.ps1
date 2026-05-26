function Test-MtCisDevicesWithoutCompliancePolicyMarkedCompliance {
    <#
    .SYNOPSIS
    Checks if devices without a compliance policy assigned are marked "not compliant".

    .DESCRIPTION
    Devices without a compliance policy assigned should be marked "not compliant".
        CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisDevicesWithoutCompliancePolicyMarkedCompliance
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
        $settings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/deviceManagement/settings' -DisableCache

        Write-Verbose 'Executing checks'
        $checkSecureByDefault = $settings | Where-Object { $_.secureByDefault -eq $true }

        $testResult = (($checkSecureByDefault | Measure-Object).Count -ge 1)
        if ($checkSecureByDefault) {
            $checkSecureByDefaultResult = '✅ Pass'
        }
        else {
            $checkSecureByDefaultResult = '❌ Fail'
        }


        return $testResult
    }
    catch {
        return $null
    }

}
