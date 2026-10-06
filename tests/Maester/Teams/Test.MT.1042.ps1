function Test-MtCheckMT1042 {
    <#
    .SYNOPSIS
    Restrict dial-in users from bypassing a meeting lobby

    .DESCRIPTION
    Checks that AllowPSTNUsersToBypassLobby in the Global Teams meeting policy is False.
    #>
    [MaesterTest(
        Id = 'MT.1042',
        Title = 'Restrict dial-in users from bypassing a meeting lobby',
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

    $result = $TeamsMeetingPolicyGlobal.AllowPSTNUsersToBypassLobby

    if ($result -eq $false) {
        $testResultMarkdown = "Well done. AllowPSTNUsersToBypassLobby is $($result)`n`n"
    } else {
        $testResultMarkdown = "AllowPSTNUsersToBypassLobby in [Meeting policies]($portalLink_MeetingPolicy) should be ``False`` and is ``$($result)`` `n`n"
    }
    $testDetailsMarkdown = "Dial-in users aren’t authenticated though the Teams app. Increase the security of your meetings by preventing these unknown users from bypassing the lobby and immediately joining the meeting."
    Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

    return ($result -eq $false)
}
