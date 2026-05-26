function Test-MtCisThirdPartyFileSharingCompliance {
    <#
    .SYNOPSIS
    Ensure third-party file sharing cloud services in Teams are disabled

    .DESCRIPTION
    Ensure third-party file sharing cloud services in Teams are disabled
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisThirdPartyFileSharingCompliance
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
        $null = Get-CsTenant -ErrorAction Stop
    } catch {
        Write-Verbose "Not connected to Microsoft Teams: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    Write-Verbose 'Test-MtCisThirdPartyFileSharing: Checking if third-party file sharing cloud services in Teams are disabled'

    try {
        $return = $true
        $thirdPartyCloudServices = Get-CsTeamsClientConfiguration -Identity Global | Select-Object AllowDropbox, AllowBox, AllowGoogleDrive, AllowShareFile, AllowEgnyte

        $passResult = '✅ Pass'
        $failResult = '❌ Fail'

        $result = "| Policy | Value | Status |`n"
        $result += "| --- | --- | --- |`n"

        foreach ($thirdPartyProvider in ($thirdPartyCloudServices.PSObject.Properties)) {
            if ($thirdPartyProvider.Value -eq $false) {
                $result += "| $($thirdPartyProvider.Name) | $($thirdPartyProvider.Value) | $passResult |`n"
            } else {
                $result += "| $($thirdPartyProvider.Name) | $($thirdPartyProvider.Value) | $failResult |`n"
                $return = $false
            }
        }

        if ($return) {
        } else {
        }

        return $return
    } catch {
        return $null
    }

}
