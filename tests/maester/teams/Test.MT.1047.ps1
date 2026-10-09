function Test-MtCheckMT1047 {
    <#
    .SYNOPSIS
    Restrict anonymous users from starting Teams meetings

    .DESCRIPTION
    Checks that AllowAnonymousUsersToStartMeeting in the Global Teams meeting policy is False.
    #>
    [MaesterTest(
        Id = 'MT.1047',
        Title = 'Restrict anonymous users from starting Teams meetings',
        Severity = 'Medium',
        Category = 'Maester/Teams',
        Tag = ('Maester', 'Teams'),
        Service = 'Teams',
        Author = 'weyCC81',
        Contributor = ('merill', 'svrooij')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $TeamsMeetingPolicyGlobal = Get-CsTeamsMeetingPolicy | Where-Object { $_.Identity -eq "Global" }
    Write-Verbose "Found Global Teams Meeting policy ``$($TeamsMeetingPolicyGlobal.Identity)``"
    $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

    $result = $TeamsMeetingPolicyGlobal.AllowAnonymousUsersToStartMeeting

    if ($result -eq $false) {
        $testResultMarkdown = "Well done. AllowAnonymousUsersToStartMeeting is $($result)`n`n"
    } else {
        $testResultMarkdown = "AllowAnonymousUsersToStartMeeting in [Meeting policies]($portalLink_MeetingPolicy) should be ``False`` and is ``$($result)`` `n`n"
    }
    $testDetailsMarkdown = "If anonymous users are allowed to start meetings, they can admit any users from the lobbies, authenticated or otherwise. Anonymous users haven’t been authenticated, which can increase the risk of data leakage."
    Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

    return ($result -eq $false)
}
