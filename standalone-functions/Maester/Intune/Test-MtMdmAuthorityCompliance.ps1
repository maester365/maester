function Test-MtMdmAuthorityCompliance {
    <#
    .SYNOPSIS
    Check the MDM Authority for Intune.

    .DESCRIPTION
    This command checks the Mobile Device Management (MDM) Authority setting in Microsoft Intune to determine if Intune is the configured MDM authority.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtMdmAuthorityCompliance
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
    Write-Verbose 'Testing MDM Authority...'

    try {
        Write-Verbose 'Retrieving MDM Authority status...'
        $org = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/organization'
        $detailedOrgInfo = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/organization/$($org.id)?`$select=mobiledevicemanagementauthority'
        return $detailedOrgInfo.mobileDeviceManagementAuthority -eq 'intune'
    } catch {
        return $null
    }

}
