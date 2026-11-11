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
        Control            = 'cisa-scuba:MS.TEAMS.1.7',
        Service            = 'Teams',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-MtCisaTeamsGlobalMeetingBroadcastPolicy
    $setting = $policy.PSObject.Properties['BroadcastRecordingMode']
    if ($null -eq $setting -or [string]::IsNullOrWhiteSpace([string]$setting.Value)) {
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
