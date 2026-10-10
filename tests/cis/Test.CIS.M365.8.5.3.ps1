function Test-MtCisTeamsLobbyBypass {
    <#
    .SYNOPSIS
    Ensure only people in my org can bypass the lobby

    .DESCRIPTION
    Only people in my org can bypass the lobby
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.5.3, L1)

    .EXAMPLE
    Test-MtCisTeamsLobbyBypass

    Returns true if only people in my org can bypass the lobby

    .LINK
    https://maester.dev/docs/commands/Test-MtCisTeamsLobbyBypass
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.5.3',
        Title = 'Ensure only people in my org can bypass the lobby',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Teams',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS M365 v7.0.0', 'L1'),
        Service = 'Teams',
        Author = 'HenrikPiecha',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsLobbyBypass: Testing if only people in my org can bypass the lobby'
    $TeamsMeetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global | Select-Object -ExpandProperty AutoAdmittedUsers
    if ($TeamsMeetingPolicy -eq 'InvitedUsers' -or $TeamsMeetingPolicy -eq 'EveryoneInCompanyExcludingGuests' -or $TeamsMeetingPolicy -eq 'OrganizerOnly') {
        Add-MtTestResultDetail -Result 'Well done. Only people in your org can bypass the lobby.'
        return $true
    } else {
        Add-MtTestResultDetail -Result "Following people can bypass your lobby: '$($TeamsMeetingPolicy)'."
        return $false
    }
}
