function Test-MtCheckMT1045 {
    <#
    .SYNOPSIS
    Only invited users should be automatically admitted to Teams meetings

    .DESCRIPTION
    Checks that AutoAdmittedUsers in the Global Teams meeting policy is InvitedUsers.
    #>
    [MaesterTest(
        Id = 'MT.1045',
        Title = 'Only invited users should be automatically admitted to Teams meetings',
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
    if (-not $TeamsMeetingPolicyGlobal) {
        # 2.x failed this test when no Global Teams Meeting Policy exists.
        return $false
    }
    $portalLink_MeetingPolicy = "https://admin.teams.microsoft.com/policies/meetings"

    $result = $TeamsMeetingPolicyGlobal.AutoAdmittedUsers

    if ($result -eq "InvitedUsers") {
        $testResultMarkdown = "Well done. AutoAdmittedUsers is $($result)`n`n"
    } else {
        $testResultMarkdown = "AutoAdmittedUsers in [Meeting policies]($portalLink_MeetingPolicy) should be ``InvitedUsers`` and is ``$($result)`` `n`n"
    }
    $testDetailsMarkdown = "Users who aren’t invited to a meeting shouldn’t be let in automatically, because it increases the risk of data leaks, inappropriate content being shared, or malicious actors joining. If only invited users are automatically admitted, then users who weren’t invited will be sent to a meeting lobby. The host can then decide whether or not to let them in."
    Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

    return ($result -eq 'InvitedUsers')
}
