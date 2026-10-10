function Test-MtCheckMT1048 {
    <#
    .SYNOPSIS
    Limit external participants from having control in a Teams meeting

    .DESCRIPTION
    Checks that AllowExternalParticipantGiveRequestControl in the Global Teams meeting policy is False.
    #>
    [MaesterTest(
        Id = 'MT.1048',
        Title = 'Limit external participants from having control in a Teams meeting',
        Severity = 'Medium',
        Category = 'Maester/Teams',
        Product = 'Teams',
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

    $result = $TeamsMeetingPolicyGlobal.AllowExternalParticipantGiveRequestControl

    if ($result -eq $false) {
        $testResultMarkdown = "Well done. AllowExternalParticipantGiveRequestControl is $($result)`n`n"
    } else {
        $testResultMarkdown = "AllowExternalParticipantGiveRequestControl in [Meeting policies]($portalLink_MeetingPolicy) should be ``False`` and is ``$($result)`` `n`n"
    }
    $testDetailsMarkdown = "External participants are users that are outside your organization. Limiting their permission to share content, add new users, and more protects your organization’s information from data leaks, inappropriate content being shared, or malicious actors joining the meeting."
    Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

    return ($result -eq $false)
}
