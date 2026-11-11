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
        Control            = 'cisa-scuba:MS.TEAMS.2.2',
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

        $inbound = $configuration.PSObject.Properties['AllowTeamsConsumerInbound']
        $consumer = $configuration.PSObject.Properties['AllowTeamsConsumer']
        $inboundValue = if ($inbound -and $inbound.Value -is [bool]) {
            [string]$inbound.Value
        }
        else {
            'Unknown'
        }
        $consumerValue = if ($consumer -and $consumer.Value -is [bool]) {
            [string]$consumer.Value
        }
        else {
            'Unknown'
        }

        $policyPass = $null
        if ($consumer -and $consumer.Value -is [bool] -and -not $consumer.Value) {
            $policyPass = $true
        }
        elseif ($inbound -and $inbound.Value -is [bool] -and -not $inbound.Value) {
            $policyPass = $true
        }
        elseif ($inbound -and $consumer -and $inbound.Value -is [bool] -and $consumer.Value -is [bool]) {
            $policyPass = $false
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
            Policy                       = $identity
            AllowTeamsConsumerInbound    = $inboundValue
            AllowTeamsConsumer           = $consumerValue
            Pass                         = $policyPass
            Result                       = $status
        }
    }

    $violatingPolicies = @($results | Where-Object { $_.Pass -eq $false } | ForEach-Object { $_.Policy })
    $unknownPolicies = @($results | Where-Object { $null -eq $_.Pass } | ForEach-Object { $_.Policy })
    if ($violatingPolicies.Count -eq 0 -and $unknownPolicies.Count -gt 0) {
        $policyList = $unknownPolicies -join ', '
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "The tenant does not expose the settings required to assess unmanaged inbound contact for: $policyList."
        return $null
    }

    $passed = $violatingPolicies.Count -eq 0
    $result = if ($passed) {
        'Well done. Unmanaged users cannot initiate contact with internal users in any federation configuration.'
    } else {
        'Both unmanaged contact and inbound unmanaged contact are enabled in one or more federation configurations.'
    }
    $result += "`n`n| Policy | AllowTeamsConsumerInbound | AllowTeamsConsumer | Result |`n| --- | --- | --- | --- |`n"
    foreach ($row in $results) {
        $result += "| $($row.Policy) | $($row.AllowTeamsConsumerInbound) | $($row.AllowTeamsConsumer) | $($row.Result) |`n"
    }
    Add-MtTestResultDetail -Result $result
    return $passed
}
