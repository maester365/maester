function Test-MtManagedDeviceCleanupSettingsCompliance {
    <#
    .SYNOPSIS
    Ensure device clean-up rule is configured

    .DESCRIPTION
    The device clean-up rule should be configured
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtManagedDeviceCleanupSettingsCompliance
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
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose 'Testing device clean-up rule configuration'

    try {
        $deviceCleanupSettings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/managedDeviceCleanupRules'
        if ((-not $deviceCleanupSettings.deviceInactivityBeforeRetirementInDays) -or ($deviceCleanupSettings.deviceInactivityBeforeRetirementInDays -eq 0)) {
            $return = $false
        } else {
            $return = $true
        }
        return $return
    } catch {
        return $null
    }

}
