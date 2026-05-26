function Test-MtCisCommunicateInitiateExternalTeamsUsersCompliance {
    <#
    .SYNOPSIS
    Ensure external Teams users cannot initiate conversations

    .DESCRIPTION
    External Teams users cannot initiate conversations
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisCommunicateInitiateExternalTeamsUsersCompliance
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

    Write-Verbose 'Test-MtCisCommunicateInitiateExternalTeamsUsers: Checking if external unmanaged Teams users cannot initiate conversations'

    try {
        $AllowTeamsConsumerInbound = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowTeamsConsumerInbound
        if ($AllowTeamsConsumerInbound -eq $false) {
            return $true
        }
        else {
            $ExternalAccessPolicy = Get-CsExternalAccessPolicy -Identity Global
            if ($ExternalAccessPolicy.EnableTeamsConsumerInbound -eq $false) {
                return $true
            }
            else {
                return $false
            }
        }
    }
    catch {
        return $null
    }

}
