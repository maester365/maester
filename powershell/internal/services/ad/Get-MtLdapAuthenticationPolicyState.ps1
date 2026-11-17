function Get-MtLdapAuthenticationPolicyState {
    <#
    .SYNOPSIS
    Collects Authentication Policies and Authentication Policy Silos over the validated LDAP connection.
    .DESCRIPTION
    Reads policy and silo objects from the configuration naming context. Optional expression
    attributes omitted by LDAP are represented as null values; omission alone does not establish
    whether an attribute is unconfigured or withheld by access controls.
    .EXAMPLE
    Get-MtLdapAuthenticationPolicyState -Connection $Connection -ConfigurationNamingContext $RootDse.ConfigurationNamingContext
    .NOTES
    Author: Mario Contestabile
    LinkedIn: https://www.linkedin.com/in/mario-contestabile/
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Connection,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationNamingContext
    )

    $searchBase = "CN=AuthN Policy Configuration,CN=Services,$ConfigurationNamingContext"
    $policyAttributes = @(
        'distinguishedName', 'name', 'objectClass', 'whenCreated', 'whenChanged',
        'msDS-AuthNPolicyEnforced', 'msDS-StrongNTLMPolicy',
        'msDS-UserAllowedToAuthenticateFrom', 'msDS-UserAllowedToAuthenticateTo',
        'msDS-ServiceAllowedToAuthenticateFrom', 'msDS-ServiceAllowedToAuthenticateTo',
        'msDS-ComputerAllowedToAuthenticateTo'
    )
    $siloAttributes = @(
        'distinguishedName', 'name', 'objectClass', 'whenCreated', 'whenChanged',
        'msDS-AuthNPolicySiloEnforced', 'msDS-UserAuthNPolicy',
        'msDS-ServiceAuthNPolicy', 'msDS-ComputerAuthNPolicy', 'msDS-AuthNPolicySiloMembers'
    )

    $policies = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $searchBase -Scope Subtree -Filter '(objectClass=msDS-AuthNPolicy)' -Attributes $policyAttributes | Where-Object { $null -ne $_ })
    $silos = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $searchBase -Scope Subtree -Filter '(objectClass=msDS-AuthNPolicySilo)' -Attributes $siloAttributes | Where-Object { $null -ne $_ })

    $getValue = {
        param([object]$InputObject,[string]$Name)
        $property = $InputObject.PSObject.Properties[$Name]
        if ($null -eq $property) { return $null }
        return $property.Value
    }
    $convertLdapBoolean = {
        param([object]$Value)
        if ($Value -is [bool]) { return [bool]$Value }
        if ($null -eq $Value) { return $false }
        switch -Regex (([string]$Value).Trim()) {
            '^(?i:true|1)$' { return $true }
            '^(?i:false|0)$' { return $false }
            default { return $false }
        }
    }

    $normalizedPolicies = foreach ($policy in $policies) {
        [PSCustomObject][ordered]@{
            Name                               = [string](& $getValue $policy 'Name')
            DistinguishedName                  = [string](& $getValue $policy 'DistinguishedName')
            Enforced                           = & $convertLdapBoolean (& $getValue $policy 'msDS-AuthNPolicyEnforced')
            StrongNTLMPolicy                   = & $getValue $policy 'msDS-StrongNTLMPolicy'
            UserAllowedToAuthenticateFrom      = & $getValue $policy 'msDS-UserAllowedToAuthenticateFrom'
            UserAllowedToAuthenticateTo        = & $getValue $policy 'msDS-UserAllowedToAuthenticateTo'
            ServiceAllowedToAuthenticateFrom   = & $getValue $policy 'msDS-ServiceAllowedToAuthenticateFrom'
            ServiceAllowedToAuthenticateTo     = & $getValue $policy 'msDS-ServiceAllowedToAuthenticateTo'
            ComputerAllowedToAuthenticateTo    = & $getValue $policy 'msDS-ComputerAllowedToAuthenticateTo'
        }
    }
    $normalizedSilos = foreach ($silo in $silos) {
        $members = & $getValue $silo 'msDS-AuthNPolicySiloMembers'
        [PSCustomObject][ordered]@{
            Name                = [string](& $getValue $silo 'Name')
            DistinguishedName   = [string](& $getValue $silo 'DistinguishedName')
            Enforced            = & $convertLdapBoolean (& $getValue $silo 'msDS-AuthNPolicySiloEnforced')
            UserAuthNPolicy     = & $getValue $silo 'msDS-UserAuthNPolicy'
            ServiceAuthNPolicy  = & $getValue $silo 'msDS-ServiceAuthNPolicy'
            ComputerAuthNPolicy = & $getValue $silo 'msDS-ComputerAuthNPolicy'
            Members             = if ($null -ne $members) { @($members) } else { @() }
        }
    }

    return [PSCustomObject][ordered]@{
        Policies            = @($normalizedPolicies)
        Silos               = @($normalizedSilos)
        PolicyCount         = @($normalizedPolicies).Count
        SiloCount           = @($normalizedSilos).Count
        EnforcedPolicyCount = @($normalizedPolicies | Where-Object { $_.Enforced }).Count
        EnforcedSiloCount   = @($normalizedSilos | Where-Object { $_.Enforced }).Count
        NonEnforcedSilos    = @($normalizedSilos | Where-Object { -not $_.Enforced } | ForEach-Object { $_.Name })
    }
}
