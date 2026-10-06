function Test-MtCheckMT1046 {
    <#
    .SYNOPSIS
    Restrict anonymous users from joining meetings

    .DESCRIPTION
    Checks that AllowAnonymousUsersToJoinMeeting in the Global Teams meeting policy is False.
    #>
    [MaesterTest(
        Id = 'MT.1046',
        Title = 'Restrict anonymous users from joining meetings',
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

    $result = $TeamsMeetingPolicyGlobal.AllowAnonymousUsersToJoinMeeting

    if ($result -eq $false) {
        $testResultMarkdown = "Well done. AllowAnonymousUsersToJoinMeeting is $($result)`n`n"
    } else {
        $testResultMarkdown = "AllowAnonymousUsersToJoinMeeting in [Meeting policies]($portalLink_MeetingPolicy) should be ``False`` and is ``$($result)`` `n`n"
    }
    $testDetailsMarkdown = "By restricting anonymous users from joining Microsoft Teams meetings, you have full control over meeting access. Anonymous users may not be from your organization and could have joined for malicious purposes, such as gaining information about your organization through conversations."
    Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

    return ($result -eq $false)
}
