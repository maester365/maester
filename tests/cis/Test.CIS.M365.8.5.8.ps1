function Test-MtCisTeamsExternalMeetingChat {
    <#
    .SYNOPSIS
        Ensure external meeting chat is off

    .DESCRIPTION
        Checks that the Global meeting policy does not let users take part in external meeting chats with
        untrusted organizations.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.5.8, L2)

    .EXAMPLE
        Test-MtCisTeamsExternalMeetingChat

        Returns true if external meeting chat with untrusted organizations is off.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsExternalMeetingChat
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.5.8',
        Title = 'Ensure external meeting chat is off',
        Product = 'teams',
        Feature = 'meetings',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:8.5.8', 'nist-800-53-r5:AC-3'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsExternalMeetingChat: Checking the Global meeting policy'
    $meetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global
    $setting = $meetingPolicy.AllowExternalNonTrustedMeetingChat
    $testResult = $setting -eq $false

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Users cannot take part in external meeting chats with untrusted organizations.`n`n"
    } else {
        "Users can take part in external meeting chats with untrusted organizations.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| AllowExternalNonTrustedMeetingChat | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
