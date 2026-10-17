function Test-MtCisTeamsMeetingRecording {
    <#
    .SYNOPSIS
        Ensure meeting recording is off by default

    .DESCRIPTION
        Checks that the Global meeting policy has cloud meeting recording turned off by default.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.5.9, L2)

    .EXAMPLE
        Test-MtCisTeamsMeetingRecording

        Returns true if meeting recording is off by default.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsMeetingRecording
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.5.9',
        Title = 'Ensure meeting recording is off by default',
        Product = 'teams',
        Feature = 'meetings',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:8.5.9', 'nist-800-53-r5:CM-7'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsMeetingRecording: Checking the Global meeting policy'
    $meetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global
    $setting = $meetingPolicy.AllowCloudRecording
    $testResult = $setting -eq $false

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Meeting recording is off by default.`n`n"
    } else {
        "Meeting recording is on by default.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| AllowCloudRecording | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
