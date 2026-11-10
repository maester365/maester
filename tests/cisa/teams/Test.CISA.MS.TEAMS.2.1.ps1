function Test-MtCisaTeamsExternalAccessScope {
    <#
    .SYNOPSIS
    Checks that external access is limited to approved domains.

    .DESCRIPTION
    Checks the Teams tenant federation configuration. External access may be disabled or restricted to one
    or more allowed domains.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.2.1',
        Title              = 'External access for users SHALL only be enabled on a per-domain basis.',
        Product            = 'teams',
        Feature            = 'external-access',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = ('T1199', 'T1204.001'),
        Control            = ('cisa-scuba:MS.TEAMS.2.1', 'nist-800-53-r5:AC-3'),
        Service            = 'Teams',
        Author             = 'Copilot'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $configuration = Get-MtCisaTeamsFederationConfiguration
    $federatedUsers = $configuration.PSObject.Properties['AllowFederatedUsers']
    $allowedDomains = $configuration.PSObject.Properties['AllowedDomains']
    if ($null -eq $federatedUsers -or $federatedUsers.Value -isnot [bool]) {
        throw 'Teams federation configuration did not return a Boolean AllowFederatedUsers value.'
    }

    $allowAllKnownDomains = $false
    $domainDisplay = 'Not required because federation is disabled'
    if ($federatedUsers.Value) {
        if ($null -eq $allowedDomains -or $null -eq $allowedDomains.Value) {
            throw 'Teams federation configuration did not return AllowedDomains.'
        }

        $domainPolicy = $allowedDomains.Value
        $allowAllKnownDomains = "$($domainPolicy.PSObject.TypeNames -join ' ') $domainPolicy" -match 'AllowAllKnownDomains'
        $domainDisplay = if ($allowAllKnownDomains) {
            'AllowAllKnownDomains'
        } elseif ($domainPolicy.PSObject.Properties['AllowedDomain']) {
            @($domainPolicy.AllowedDomain) -join ', '
        } else {
            "$domainPolicy"
        }
    }

    $passed = -not $federatedUsers.Value -or -not $allowAllKnownDomains
    $result = if ($passed) {
        'Well done. External access is disabled or restricted to allowed domains.'
    } else {
        'External access is enabled for all domains. Add approved domains or disable external access.'
    }
    $result += "`n`n| Setting | Value | Result |`n| --- | --- | --- |`n"
    $result += "| AllowFederatedUsers | $($federatedUsers.Value) | $(if ($passed) { 'Pass' } else { 'Fail' }) |`n"
    $result += "| AllowedDomains | $domainDisplay | $(if ($passed) { 'Pass' } else { 'Fail' }) |"
    Add-MtTestResultDetail -Result $result
    return $passed
}
