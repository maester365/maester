function Get-MtCisaTeamsGlobalMeetingBroadcastPolicy {
    [CmdletBinding()]
    [OutputType([object])]
    param()

    $cacheKey = 'GlobalMeetingBroadcastPolicy'
    if (-not $__MtSession.TeamsCache.ContainsKey($cacheKey)) {
        $policies = @(Get-CsTeamsMeetingBroadcastPolicy -Identity Global -ErrorAction Stop)
        if ($policies.Count -ne 1 -or $policies[0].Identity -ne 'Global') {
            throw 'Teams did not return exactly one Global meeting broadcast policy.'
        }
        $__MtSession.TeamsCache[$cacheKey] = $policies[0]
    }

    return $__MtSession.TeamsCache[$cacheKey]
}
