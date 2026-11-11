function Get-MtCisaTeamsGlobalMeetingPolicy {
    [CmdletBinding()]
    param()

    $policies = Get-MtCisaTeamsMeetingPolicies -GlobalOnly
    return $policies[0]
}
