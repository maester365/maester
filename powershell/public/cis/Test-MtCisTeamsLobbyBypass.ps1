<#
.SYNOPSIS
    Ensure only people in my org can bypass the lobby

.DESCRIPTION
    Only people in my org can bypass the lobby

.EXAMPLE
    Test-MtCisTeamsLobbyBypass

    Returns true if only people in my org can bypass the lobby

.LINK
    https://maester.dev/docs/commands/
#>
function Test-MtCisTeamsLobbyBypass {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

    $return = $true
    try {
        $TeamsMeetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global | Select-Object -ExpandProperty AutoAdmittedUsers
        if ($TeamsMeetingPolicy -eq "EveryoneInCompanyExcludingGuests") {
            Add-MtTestResultDetail -Result "Well done. Only people in your org (excluding guests) can bypass the lobby."
        } else {
            Add-MtTestResultDetail -Result "Following people can bypass your lobby: '$($TeamsMeetingPolicy)'."
            $return = $false
        }
    } catch {
        $return = $false
        Write-Error $_.Exception.Message
    }
    return $return
}