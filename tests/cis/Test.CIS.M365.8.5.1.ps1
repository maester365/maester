function Test-MtCisTeamsAnonymousJoin {
    <#
    .SYNOPSIS
        Ensure anonymous users can't join a meeting

    .DESCRIPTION
        Checks that the Global meeting policy does not allow anonymous users to join meetings.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.5.1, L2)

    .EXAMPLE
        Test-MtCisTeamsAnonymousJoin

        Returns true if anonymous users cannot join meetings.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsAnonymousJoin
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.5.1',
        Title = 'Ensure anonymous users can''t join a meeting',
        Product = 'teams',
        Feature = 'meetings',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:8.5.1', 'nist-800-53-r5:AC-3'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsAnonymousJoin: Checking the Global meeting policy'
    $meetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global
    $setting = $meetingPolicy.AllowAnonymousUsersToJoinMeeting
    $testResult = $setting -eq $false

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Anonymous users cannot join meetings.`n`n"
    } else {
        "Anonymous users can join meetings.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| AllowAnonymousUsersToJoinMeeting | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
