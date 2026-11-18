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
        Control            = 'cisa-scuba:MS.TEAMS.2.3',
        Service            = ('Graph', 'Teams'),
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (Test-MtCisaTeamsIsUSGovernment) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'This policy is not applicable to GCC, GCC High, or DoD environments.'
        return $null
    }

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

        $setting = $configuration.PSObject.Properties['AllowTeamsConsumer']
        $value = if ($setting -and $setting.Value -is [bool]) {
            [string]$setting.Value
        }
        else {
            'Unknown'
        }
        $policyPass = if ($setting -and $setting.Value -is [bool]) {
            -not $setting.Value
        }
        else {
            $null
        }
        $status = if ($null -eq $policyPass) {
            'Unknown'
        }
        elseif ($policyPass) {
            'Pass'
        }
        else {
            'Fail'
        }

        [pscustomobject]@{
            Policy            = $identity
            AllowTeamsConsumer = $value
            Pass              = $policyPass
            Result            = $status
        }
    }

    $violatingPolicies = @($results | Where-Object { $_.Pass -eq $false } | ForEach-Object { $_.Policy })
    $unknownPolicies = @($results | Where-Object { $null -eq $_.Pass } | ForEach-Object { $_.Policy })
    if ($violatingPolicies.Count -eq 0 -and $unknownPolicies.Count -gt 0) {
        $policyList = $unknownPolicies -join ', '
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "The tenant does not expose the setting required to assess internal contact with unmanaged users for: $policyList."
        return $null
    }

    $passed = $violatingPolicies.Count -eq 0
    $result = if ($passed) {
        'Well done. Internal users cannot initiate contact with unmanaged users in any federation configuration.'
    } else {
        'AllowTeamsConsumer is enabled in one or more federation configurations, so internal users can initiate contact with unmanaged users.'
    }
    $result += "`n`n| Policy | AllowTeamsConsumer | Result |`n| --- | --- | --- |`n"
    foreach ($row in $results) {
        $result += "| $($row.Policy) | $($row.AllowTeamsConsumer) | $($row.Result) |`n"
    }
    Add-MtTestResultDetail -Result $result
    return $passed
}
