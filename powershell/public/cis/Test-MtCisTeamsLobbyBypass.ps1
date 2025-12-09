<#
.SYNOPSIS
    Ensure only people in my org can bypass the lobby

.DESCRIPTION
    Only people in my org can bypass the lobby
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisTeamsLobbyBypass

    Returns true if only people in my org can bypass the lobby

.LINK
    https://maester.dev/docs/commands/Test-MtCisTeamsLobbyBypass
#>
function Test-MtCisTeamsLobbyBypass {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

    Write-Verbose 'Test-MtCisTeamsLobbyBypass: Testing if only people in my org can bypass the lobby'
    try {
        $TeamsMeetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global | Select-Object -ExpandProperty AutoAdmittedUsers
        if ($TeamsMeetingPolicy -eq 'EveryoneInCompanyExcludingGuests') {
            Add-MtTestResultDetail -Result 'Well done. Only people in your org (excluding guests) can bypass the lobby.'
            return $true
        } else {
            Add-MtTestResultDetail -Result "Following people can bypass your lobby: '$($TeamsMeetingPolicy)'."
            return $false
        }
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
