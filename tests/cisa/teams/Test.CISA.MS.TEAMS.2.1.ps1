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
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = ('T1199', 'T1204.001'),
        Control            = 'cisa-scuba:MS.TEAMS.2.1',
        Service            = 'Teams',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $configurations = @(Get-MtCisaTeamsFederationConfigurations)
    $index = 0
    $results = foreach ($configuration in $configurations) {
        $index++
        $identityProperty = $configuration.PSObject.Properties['Identity']
        $identity = if ($identityProperty -and $identityProperty.Value) {
            [string]$identityProperty.Value
        }
        else {
            "Configuration $index"
        }

        $federatedUsers = $configuration.PSObject.Properties['AllowFederatedUsers']
        $allowedDomains = $configuration.PSObject.Properties['AllowedDomains']
        if ($null -eq $federatedUsers -or $federatedUsers.Value -isnot [bool]) {
            throw "Teams federation configuration '$identity' did not return a Boolean AllowFederatedUsers value."
        }

        $allowAllKnownDomains = $false
        $domainDisplay = 'Not required because federation is disabled'
        if ($federatedUsers.Value) {
            if ($null -eq $allowedDomains -or $null -eq $allowedDomains.Value) {
                throw "Teams federation configuration '$identity' did not return AllowedDomains."
            }

            $domainPolicy = $allowedDomains.Value
            $allowAllKnownDomains = ($domainPolicy.PSObject.TypeNames -join ' ') -match 'AllowAllKnownDomains'
            if ($allowAllKnownDomains) {
                $domainDisplay = 'AllowAllKnownDomains'
            }
            elseif ($domainPolicy.PSObject.Properties['AllowedDomain']) {
                $domainDisplay = @($domainPolicy.AllowedDomain) -join ', '
            }
            else {
                $domainDisplay = "$domainPolicy"
            }
        }

        [pscustomobject]@{
            Policy             = $identity
            AllowFederatedUsers = $federatedUsers.Value
            AllowedDomains     = $domainDisplay
            Pass               = (-not $federatedUsers.Value -or -not $allowAllKnownDomains)
        }
    }

    $passed = @($results | Where-Object { -not $_.Pass }).Count -eq 0
    $result = if ($passed) {
        'Well done. External access is disabled or restricted to allowed domains for every federation configuration.'
    } else {
        'External access is enabled for all domains in one or more federation configurations. Add approved domains or disable external access.'
    }
    $result += "`n`n| Policy | AllowFederatedUsers | AllowedDomains | Result |`n| --- | --- | --- | --- |`n"
    foreach ($row in $results) {
        $status = if ($row.Pass) { 'Pass' } else { 'Fail' }
        $result += "| $($row.Policy) | $($row.AllowFederatedUsers) | $($row.AllowedDomains) | $status |`n"
    }
    Add-MtTestResultDetail -Result $result
    return $passed
}
