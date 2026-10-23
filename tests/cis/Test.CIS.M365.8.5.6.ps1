function Test-MtCisTeamsPresenterRole {
    <#
    .SYNOPSIS
        Ensure only organizers and co-organizers can present

    .DESCRIPTION
        Checks that the Global meeting policy limits the presenter role to organizers and co-organizers.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.5.6, L2)

    .EXAMPLE
        Test-MtCisTeamsPresenterRole

        Returns true if only organizers and co-organizers can present.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsPresenterRole
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.5.6',
        Title = 'Ensure only organizers and co-organizers can present',
        Product = 'teams',
        Feature = 'meetings',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1566.003',
        Control = ('cis-m365:8.5.6', 'nist-800-53-r5:AC-3'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsPresenterRole: Checking the Global meeting policy'
    $meetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global
    $setting = $meetingPolicy.DesignatedPresenterRoleMode
    $testResult = $setting -eq 'OrganizerOnlyUserOverride'

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Only organizers and co-organizers can present.`n`n"
    } else {
        "Other participants can take over presentation and share their screen.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| DesignatedPresenterRoleMode | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
