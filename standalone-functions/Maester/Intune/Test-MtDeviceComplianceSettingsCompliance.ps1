function Test-MtDeviceComplianceSettingsCompliance {
    <#
    .SYNOPSIS
    Ensure the built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'

    .DESCRIPTION
    The built-in Device Compliance Policy should mark devices with no compliance policy assigned as 'Not compliant'
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtDeviceComplianceSettingsCompliance
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

    try {
        $deviceComplianceSettings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/settings'
        Write-Verbose "Device Compliance Settings: $deviceComplianceSettings"
        if ($deviceComplianceSettings.secureByDefault -ne $true) {
            $return = $false
        } else {
            $return = $true
        }
        return $return
    } catch {
        return $null
    }

}
