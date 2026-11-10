function Test-MtCisaTeamsUnmanagedInboundContact {
    <#
    .SYNOPSIS
    Checks that unmanaged users cannot initiate contact with internal users.

    .DESCRIPTION
    This policy is not applicable to US Government tenant regions and its settings may be unavailable in some
    tenants. Disabling either inbound unmanaged contact or unmanaged contact entirely satisfies the requirement.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.2.2',
        Title              = 'Unmanaged users SHALL NOT be enabled to initiate contact with internal users.',
        Product            = 'teams',
        Feature            = 'external-access',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1204.001',
        Control            = ('cisa-scuba:MS.TEAMS.2.2', 'nist-800-53-r5:CM-7', 'nist-800-53-r5:SI-8'),
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
    $inbound = $configuration.PSObject.Properties['AllowTeamsConsumerInbound']
    $consumer = $configuration.PSObject.Properties['AllowTeamsConsumer']

    if ($consumer -and $consumer.Value -is [bool] -and -not $consumer.Value) {
        $passed = $true
    } elseif ($inbound -and $inbound.Value -is [bool] -and -not $inbound.Value) {
        $passed = $true
    } elseif ($inbound -and $consumer -and $inbound.Value -is [bool] -and $consumer.Value -is [bool]) {
        $passed = $false
    } else {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'The tenant does not expose the settings required to assess unmanaged inbound contact.'
        return $null
    }

    $result = if ($passed) {
        'Well done. Unmanaged users cannot initiate contact with internal users.'
    } else {
        'Both unmanaged contact and inbound unmanaged contact are enabled.'
    }
    $result += "`n`n| Setting | Value |`n| --- | --- |`n"
    $result += "| AllowTeamsConsumerInbound | $($inbound.Value) |`n| AllowTeamsConsumer | $($consumer.Value) |"
    Add-MtTestResultDetail -Result $result
    return $passed
}
