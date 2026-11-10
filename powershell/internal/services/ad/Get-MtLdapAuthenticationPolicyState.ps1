function Get-MtLdapAuthenticationPolicyState {
    <#
    .SYNOPSIS
    Collects Authentication Policies and Authentication Policy Silos over the validated LDAP connection.
    .DESCRIPTION
    Reads policy and silo objects from the configuration naming context and preserves whether each
    security expression attribute was returned, null, empty, or configured. This prevents an absent
    attribute from being misreported as an intentionally unconfigured policy.
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

    # Query policies and silos separately so an empty result remains valid evidence rather than a collection failure.
    $policies = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $searchBase -Scope Subtree -Filter '(objectClass=msDS-AuthNPolicy)' -Attributes $policyAttributes | Where-Object { $null -ne $_ })
    $silos = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $searchBase -Scope Subtree -Filter '(objectClass=msDS-AuthNPolicySilo)' -Attributes $siloAttributes | Where-Object { $null -ne $_ })

    # Resolve optional LDAP properties through PSObject metadata so StrictMode does not turn an absent attribute into a collection failure.
    $getPropertyState = {
        param(
            [Parameter(Mandatory)]
            [object] $InputObject,
            [Parameter(Mandatory)]
            [string] $Name
        )

        $property = $InputObject.PSObject.Properties[$Name]
        $presenceMetadata = $InputObject.PSObject.Properties['__MtLdapPresentAttributes']
        $present = if ($null -ne $presenceMetadata) {
            $Name -in @($presenceMetadata.Value)
        }
        else {
            $null -ne $property
        }
        $value = if ($null -ne $property) { $property.Value } else { $null }
        return [PSCustomObject][ordered]@{
            Present = $present
            Value   = $value
        }
    }

    $expressionNames = @(
        'msDS-UserAllowedToAuthenticateFrom', 'msDS-UserAllowedToAuthenticateTo',
        'msDS-ServiceAllowedToAuthenticateFrom', 'msDS-ServiceAllowedToAuthenticateTo',
        'msDS-ComputerAllowedToAuthenticateTo'
    )

    $normalizedPolicies = foreach ($policy in $policies) {
        $attributeState = [ordered]@{}
        foreach ($attributeName in $expressionNames) {
            $propertyState = & $getPropertyState -InputObject $policy -Name $attributeName
            $isPresent = $propertyState.Present
            $value = $propertyState.Value
            $attributeState[$attributeName] = [PSCustomObject][ordered]@{
                Requested = $true
                Present   = $isPresent
                IsNull    = $isPresent -and $null -eq $value
                IsEmpty   = $isPresent -and $null -ne $value -and [string]::IsNullOrWhiteSpace([string]$value)
                Value     = $value
            }
        }
        $nameState = & $getPropertyState -InputObject $policy -Name 'Name'
        $distinguishedNameState = & $getPropertyState -InputObject $policy -Name 'DistinguishedName'
        $enforcedState = & $getPropertyState -InputObject $policy -Name 'msDS-AuthNPolicyEnforced'
        $strongNtlmState = & $getPropertyState -InputObject $policy -Name 'msDS-StrongNTLMPolicy'
        [PSCustomObject][ordered]@{
            Name              = [string]$nameState.Value
            DistinguishedName = [string]$distinguishedNameState.Value
            Enforced          = $enforcedState.Present -and [bool]$enforcedState.Value
            StrongNTLMPolicy  = $strongNtlmState.Value
            AttributeState    = [PSCustomObject]$attributeState
        }
    }

    $normalizedSilos = foreach ($silo in $silos) {
        $nameState = & $getPropertyState -InputObject $silo -Name 'Name'
        $distinguishedNameState = & $getPropertyState -InputObject $silo -Name 'DistinguishedName'
        $enforcedState = & $getPropertyState -InputObject $silo -Name 'msDS-AuthNPolicySiloEnforced'
        $userPolicyState = & $getPropertyState -InputObject $silo -Name 'msDS-UserAuthNPolicy'
        $servicePolicyState = & $getPropertyState -InputObject $silo -Name 'msDS-ServiceAuthNPolicy'
        $computerPolicyState = & $getPropertyState -InputObject $silo -Name 'msDS-ComputerAuthNPolicy'
        $membersState = & $getPropertyState -InputObject $silo -Name 'msDS-AuthNPolicySiloMembers'
        [PSCustomObject][ordered]@{
            Name                = [string]$nameState.Value
            DistinguishedName   = [string]$distinguishedNameState.Value
            Enforced            = $enforcedState.Present -and [bool]$enforcedState.Value
            UserAuthNPolicy     = $userPolicyState.Value
            ServiceAuthNPolicy  = $servicePolicyState.Value
            ComputerAuthNPolicy = $computerPolicyState.Value
            Members             = if ($membersState.Present) { @($membersState.Value) } else { @() }
        }
    }

    $missingRequiredAttributeCount = @(
        $normalizedPolicies | ForEach-Object {
            $_.AttributeState.PSObject.Properties.Value | Where-Object { -not $_.Present }
        }
    ).Count

    return [PSCustomObject][ordered]@{
        Policies                      = @($normalizedPolicies)
        Silos                         = @($normalizedSilos)
        PolicyCount                   = @($normalizedPolicies).Count
        SiloCount                     = @($normalizedSilos).Count
        EnforcedPolicyCount           = @($normalizedPolicies | Where-Object { $_.Enforced }).Count
        EnforcedSiloCount             = @($normalizedSilos | Where-Object { $_.Enforced }).Count
        MissingRequiredAttributeCount = $missingRequiredAttributeCount
    }
}