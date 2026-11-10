function Test-MtCisaTeamsBroadcastRecording {
    <#
    .SYNOPSIS
    Checks that live event recording is not set to Always record.

    .DESCRIPTION
    Checks only the Global meeting broadcast policy, matching the CISA baseline's scope.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.1.7',
        Title              = '"Record an event" SHOULD NOT be set to "Always record."',
        Product            = 'teams',
        Feature            = 'meetings',
        Area               = 'data-protection',
        ResourceType       = 'Tenant',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = ('cisa-scuba:MS.TEAMS.1.7', 'nist-800-53-r5:AC-21a'),
        Service            = 'Teams',
        Author             = 'Copilot'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-CsTeamsMeetingBroadcastPolicy -Identity Global -ErrorAction Stop)
    if ($policies.Count -ne 1 -or $policies[0].Identity -ne 'Global') {
        throw 'Teams did not return exactly one Global meeting broadcast policy.'
    }
    $setting = $policies[0].PSObject.Properties['BroadcastRecordingMode']
    if ($null -eq $setting) {
        throw 'The Global meeting broadcast policy did not return BroadcastRecordingMode.'
    }

    $passed = $setting.Value -ne 'AlwaysEnabled'
    $result = if ($passed) {
        'Well done. Live event recording is not set to Always record.'
    } else {
        'BroadcastRecordingMode in the Global meeting broadcast policy must not be AlwaysEnabled.'
    }
    $result += "`n`n| Setting | Value | Result |`n| --- | --- | --- |`n"
    $result += "| BroadcastRecordingMode | $(if ($null -eq $setting.Value) { 'Not set' } else { $setting.Value }) | $(if ($passed) { 'Pass' } else { 'Fail' }) |"
    Add-MtTestResultDetail -Result $result
    return $passed
}
