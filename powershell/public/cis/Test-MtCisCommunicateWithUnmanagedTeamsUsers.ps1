<#
.SYNOPSIS
    Ensure communication with unmanaged Teams users is disabled

.DESCRIPTION
    Communication with unmanaged Teams users is disabled

.EXAMPLE
    Test-MtCisCommunicateWithUnmanagedTeamsUsers

    Returns true if communication with unmanaged Teams users is disabled

.LINK
    https://maester.dev/docs/commands/
#>
function Test-MtCisCommunicateWithUnmanagedTeamsUsers {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

    $return = $true
    try {
        $AllowTeamsConsumer = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowTeamsConsumer
        $AllowTeamsConsumerInbound = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowTeamsConsumerInbound
        if (($AllowTeamsConsumer -eq $false -and $AllowTeamsConsumerInbound -eq $false) -or ($AllowTeamsConsumer -eq $false -and $AllowTeamsConsumerInbound -eq $true)) {
            Add-MtTestResultDetail -Result "Well done. Communication with unmanaged Teams users is disabled."
        } else {
            Add-MtTestResultDetail -Result "Communication with unmanaged Teams users is enabled."
            $return = $false
        }
    } catch {
        $return = $false
        Write-Error $_.Exception.Message
    }
    return $return
}