function Test-MtCisTeamsDialInLobbyBypass {
    <#
    .SYNOPSIS
        Ensure users dialing in can't bypass the lobby

    .DESCRIPTION
        Checks that the Global meeting policy does not let users who dial in by phone bypass the lobby.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.5.4, L1)

    .EXAMPLE
        Test-MtCisTeamsDialInLobbyBypass

        Returns true if dial-in users cannot bypass the lobby.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsDialInLobbyBypass
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.5.4',
        Title = 'Ensure users dialing in can''t bypass the lobby',
        Product = 'teams',
        Feature = 'meetings',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:8.5.4', 'nist-800-53-r5:AC-3'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsDialInLobbyBypass: Checking the Global meeting policy'
    $meetingPolicy = Get-CsTeamsMeetingPolicy -Identity Global
    $setting = $meetingPolicy.AllowPSTNUsersToBypassLobby
    $testResult = $setting -eq $false

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Users who dial in cannot bypass the lobby.`n`n"
    } else {
        "Users who dial in can bypass the lobby.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| AllowPSTNUsersToBypassLobby | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
