function Get-MtCisaTeamsMeetingPolicies {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'The Teams cmdlet returns a collection of meeting policies.')]
    [OutputType([object[]])]
    param(
        [switch]$GlobalOnly
    )

    if (-not $__MtSession.TeamsCache.ContainsKey('MeetingPolicies')) {
        $__MtSession.TeamsCache['MeetingPolicies'] = @(Get-CsTeamsMeetingPolicy -ErrorAction Stop)
    }

    $allPolicies = @($__MtSession.TeamsCache['MeetingPolicies'])
    if ($allPolicies.Count -eq 0) {
        throw 'Teams returned no meeting policies.'
    }

    $policies = if ($GlobalOnly) {
        @($allPolicies | Where-Object { $_.Identity -eq 'Global' })
    } else {
        $allPolicies
    }

    if ($GlobalOnly -and ($policies.Count -ne 1 -or $policies[0].Identity -ne 'Global')) {
        throw 'Teams did not return exactly one Global meeting policy.'
    }

    return $policies
}
