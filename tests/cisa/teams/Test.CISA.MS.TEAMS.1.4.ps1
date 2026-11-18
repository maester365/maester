function Test-MtCisaTeamsInternalMeetingAdmission {
    <#
    .SYNOPSIS
    Checks that internal users are admitted to Teams meetings automatically.

    .DESCRIPTION
    Checks the Global meeting policy against the values allowed by the CISA baseline.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.1.4',
        Title              = 'Internal users SHOULD be admitted to Teams meetings automatically.',
        Product            = 'teams',
        Feature            = 'meetings',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'cisa-scuba:MS.TEAMS.1.4',
        Service            = 'Teams',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-MtCisaTeamsGlobalMeetingPolicy
    $setting = $policy.PSObject.Properties['AutoAdmittedUsers']
    if ($null -eq $setting -or [string]::IsNullOrWhiteSpace([string]$setting.Value)) {
        throw 'The Global Teams meeting policy did not return AutoAdmittedUsers.'
    }

    $allowedValues = @('EveryoneInCompany', 'EveryoneInSameAndFederatedCompany', 'EveryoneInCompanyExcludingGuests')
    $passed = $setting.Value -in $allowedValues
    $result = if ($passed) {
        'Well done. Internal users are admitted automatically by the Global meeting policy.'
    } else {
        'AutoAdmittedUsers in the Global meeting policy must be set to an allowed internal-user value.'
    }
    $result += "`n`n| Setting | Value | Result |`n| --- | --- | --- |`n"
    $result += "| AutoAdmittedUsers | $($setting.Value) | $(if ($passed) { 'Pass' } else { 'Fail' }) |"
    Add-MtTestResultDetail -Result $result
    return $passed
}
