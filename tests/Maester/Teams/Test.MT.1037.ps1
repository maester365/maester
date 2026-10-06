function Test-MtCheckMT1037 {
    <#
    .SYNOPSIS
    Only users with Presenter role are allowed to present in Teams meetings

    .DESCRIPTION
    Runs the shared check Test-MtTeamsRestrictParticipantGiveRequestControl with the tenant's Teams meeting policies.
    #>
    [MaesterTest(
        Id = 'MT.1037',
        Title = 'Only users with Presenter role are allowed to present in Teams meetings',
        Severity = 'High',
        Category = 'Maester/Teams',
        Tag = ('Maester', 'Teams'),
        Service = 'Teams',
        Author = 'weyCC81',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $teamsMeetingPolicy = Get-CsTeamsMeetingPolicy
    Write-Verbose "Found $(@($teamsMeetingPolicy).Count) Teams Meeting policies"

    # Secure Score Name: Configure which users are allowed to present in Teams meetings
    $result = Test-MtTeamsRestrictParticipantGiveRequestControl -TeamsMeetingPolicy $teamsMeetingPolicy
    if ($null -eq $result) { return $null }
    return $result
}
