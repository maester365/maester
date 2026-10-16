function Test-MtCisTeamsAnonymousStartMeeting {
    <#
    .SYNOPSIS
        Checks that anonymous users cannot start a meeting in the Global meeting policy.

    .DESCRIPTION
        Checks that the Global meeting policy does not allow anonymous users to start a meeting. The test reads only AllowAnonymousUsersToStartMeeting, so it does not check the dial-in caller part of the benchmark.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.5.2, L1)

    .EXAMPLE
        Test-MtCisTeamsAnonymousStartMeeting

        Returns true if anonymous users cannot start meetings.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsAnonymousStartMeeting
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.5.2',
        Title = 'Ensure anonymous users and dial-in callers can''t start a meeting',
        Product = 'teams',
        Feature = 'meetings',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:8.5.2', 'nist-800-53-r5:AC-3'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsAnonymousStartMeeting: Checking the Global meeting policy'
    $meetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global
    $setting = $meetingPolicy.AllowAnonymousUsersToStartMeeting
    $testResult = $setting -eq $false

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Anonymous users cannot start meetings.`n`n"
    } else {
        "Anonymous users can start meetings.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| AllowAnonymousUsersToStartMeeting | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
