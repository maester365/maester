function Test-MtCisTeamsExternalControl {
    <#
    .SYNOPSIS
        Ensure external participants can't give or request control

    .DESCRIPTION
        Checks that the Global meeting policy does not let external participants give or request control
        of shared content in a meeting.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.5.7, L1)

    .EXAMPLE
        Test-MtCisTeamsExternalControl

        Returns true if external participants cannot give or request control.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsExternalControl
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.5.7',
        Title = 'Ensure external participants can''t give or request control',
        Product = 'teams',
        Feature = 'meetings',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:8.5.7', 'nist-800-53-r5:AC-3'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsExternalControl: Checking the Global meeting policy'
    $meetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global
    $setting = $meetingPolicy.AllowExternalParticipantGiveRequestControl
    $testResult = $setting -eq $false

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. External participants cannot give or request control.`n`n"
    } else {
        "External participants can give or request control.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| AllowExternalParticipantGiveRequestControl | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
