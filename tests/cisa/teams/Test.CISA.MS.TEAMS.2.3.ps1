function Test-MtCisaTeamsUnmanagedOutboundContact {
    <#
    .SYNOPSIS
    Checks that internal users cannot initiate contact with unmanaged users.

    .DESCRIPTION
    This policy is not applicable to US Government tenant regions and its setting may be unavailable in some
    tenants.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.2.3',
        Title              = 'Internal users SHOULD NOT be enabled to initiate contact with unmanaged users.',
        Product            = 'teams',
        Feature            = 'external-access',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1204.001',
        Control            = ('cisa-scuba:MS.TEAMS.2.3', 'nist-800-53-r5:CM-7', 'nist-800-53-r5:SC-7(10)(a)'),
        Service            = ('Graph', 'Teams'),
        Author             = 'Copilot'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (Test-MtCisaTeamsIsUSGovernment) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'This policy is not applicable to GCC, GCC High, or DoD environments.'
        return $null
    }

    $configuration = Get-MtCisaTeamsFederationConfiguration
    $setting = $configuration.PSObject.Properties['AllowTeamsConsumer']
    if ($null -eq $setting -or $setting.Value -isnot [bool]) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'The tenant does not expose the setting required to assess internal contact with unmanaged users.'
        return $null
    }

    $passed = -not $setting.Value
    $result = if ($passed) {
        'Well done. Internal users cannot initiate contact with unmanaged users.'
    } else {
        'AllowTeamsConsumer is enabled, so internal users can initiate contact with unmanaged users.'
    }
    $result += "`n`n| Setting | Value | Result |`n| --- | --- | --- |`n"
    $result += "| AllowTeamsConsumer | $($setting.Value) | $(if ($passed) { 'Pass' } else { 'Fail' }) |"
    Add-MtTestResultDetail -Result $result
    return $passed
}
