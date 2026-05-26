function Test-MtCisCommunicateWithUnmanagedTeamsUsersCompliance {
    <#
    .SYNOPSIS
    Ensure communication with unmanaged Teams users is disabled

    .DESCRIPTION
    Communication with unmanaged Teams users is disabled
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisCommunicateWithUnmanagedTeamsUsersCompliance
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

    Write-Verbose 'Test-MtCisCommunicateWithUnmanagedTeamsUsers: Checking if communication with unmanaged Teams users is disabled'

    try {
        $AllowTeamsConsumer = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowTeamsConsumer
        if ($AllowTeamsConsumer -eq $false) {
            return $true
        } else {
            $ExternalAccessPolicy = Get-CsExternalAccessPolicy -Identity Global
            if ($ExternalAccessPolicy.EnableTeamsConsumerAccess -eq $false) {
                return $true
            } else {
                return $false
            }
        }
    } catch {
        return $null
    }

}
