function Test-MtCisaTeamsMeetingLobbyAdmission {
    <#
    .SYNOPSIS
    Checks that anonymous users and dial-in callers are not admitted automatically.

    .DESCRIPTION
    Checks only the Global meeting policy, matching the CISA baseline's scope.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.1.3',
        Title              = 'Anonymous users and dial-in callers SHOULD NOT be admitted automatically.',
        Product            = 'teams',
        Feature            = 'meetings',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = ('cisa-scuba:MS.TEAMS.1.3', 'nist-800-53-r5:SC-15a'),
        Service            = 'Teams',
        Author             = 'Copilot'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-MtCisaTeamsGlobalMeetingPolicy
    $admission = $policy.PSObject.Properties['AutoAdmittedUsers']
    $pstnBypass = $policy.PSObject.Properties['AllowPSTNUsersToBypassLobby']
    if ($null -eq $admission -or [string]::IsNullOrWhiteSpace([string]$admission.Value)) {
        throw 'The Global Teams meeting policy did not return AutoAdmittedUsers.'
    }
    if ($null -eq $pstnBypass -or $pstnBypass.Value -isnot [bool]) {
        throw 'The Global Teams meeting policy did not return a Boolean AllowPSTNUsersToBypassLobby value.'
    }

    $passed = $admission.Value -ne 'Everyone' -and $pstnBypass.Value -eq $false
    $result = if ($passed) {
        'Well done. Anonymous users and dial-in callers are held in the lobby.'
    } else {
        'The Global meeting policy must not admit everyone automatically or allow dial-in users to bypass the lobby.'
    }
    $result += "`n`n| Setting | Value | Result |`n| --- | --- | --- |`n"
    $result += "| AutoAdmittedUsers | $($admission.Value) | $(if ($admission.Value -ne 'Everyone') { 'Pass' } else { 'Fail' }) |`n"
    $result += "| AllowPSTNUsersToBypassLobby | $($pstnBypass.Value) | $(if (-not $pstnBypass.Value) { 'Pass' } else { 'Fail' }) |"
    Add-MtTestResultDetail -Result $result
    return $passed
}
