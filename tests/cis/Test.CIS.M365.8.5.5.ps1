function Test-MtCisTeamsMeetingChatAnonymous {
    <#
    .SYNOPSIS
        Ensure meeting chat does not allow anonymous users

    .DESCRIPTION
        Checks that the Global meeting policy does not let anonymous users take part in meeting chat.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.5.5, L2)

    .EXAMPLE
        Test-MtCisTeamsMeetingChatAnonymous

        Returns true if meeting chat is disabled or does not allow anonymous users.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsMeetingChatAnonymous
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.5.5',
        Title = 'Ensure meeting chat does not allow anonymous users',
        Product = 'teams',
        Feature = 'meetings',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:8.5.5', 'nist-800-53-r5:AC-3'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsMeetingChatAnonymous: Checking the Global meeting policy'
    $meetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global
    $setting = $meetingPolicy.MeetingChatEnabledType
    $testResult = $setting -in @('EnabledExceptAnonymous', 'EnabledInMeetingOnlyForAllExceptAnonymous', 'Disabled')

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Meeting chat does not allow anonymous users.`n`n"
    } else {
        "Meeting chat allows anonymous users.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| MeetingChatEnabledType | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
