<#
.SYNOPSIS
    Ensure communication with unmanaged Teams users is disabled

.DESCRIPTION
    Communication with unmanaged Teams users is disabled
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisCommunicateWithUnmanagedTeamsUsers

    Returns true if communication with unmanaged Teams users is disabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisCommunicateWithUnmanagedTeamsUsers
#>
function Test-MtCisCommunicateWithUnmanagedTeamsUsers {
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple users.')]
    param()

    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

    Write-Verbose 'Test-MtCisCommunicateWithUnmanagedTeamsUsers: Checking if communication with unmanaged Teams users is disabled'

    try {
        $AllowTeamsConsumer = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowTeamsConsumer
        $AllowTeamsConsumerInbound = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowTeamsConsumerInbound
        if (($AllowTeamsConsumer -eq $false -and $AllowTeamsConsumerInbound -eq $false) -or ($AllowTeamsConsumer -eq $false -and $AllowTeamsConsumerInbound -eq $true)) {
            Add-MtTestResultDetail -Result 'Well done. Communication with unmanaged Teams users is disabled.'
            return $true
        } else {
            Add-MtTestResultDetail -Result 'Communication with unmanaged Teams users is enabled.'
            return $false
        }
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
