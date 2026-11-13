BeforeAll {
    $script:HelperPath = Join-Path $PSScriptRoot '../../../internal/services/ad/Get-MtLdapAuthenticationPolicyState.ps1'
    . $script:HelperPath
}

Describe 'Get-MtLdapAuthenticationPolicyState' {
    BeforeEach {
        $script:SearchResults = @{}
        function Invoke-MtLdapSearch {
            param($Connection,$SearchBase,$Scope,$Filter,$Attributes)
            $result = $script:SearchResults[$Filter]
            if ($null -eq $result) { return @() }

            foreach ($sourceItem in @($result)) {
                $properties = [ordered]@{}
                foreach ($property in $sourceItem.PSObject.Properties) {
                    $properties[$property.Name] = $property.Value
                }
                $properties['__MtLdapPresentAttributes'] = @($properties.Keys)

                foreach ($requestedAttribute in @($Attributes)) {
                    if ($requestedAttribute -in @('*', '+', '1.1', 'distinguishedName')) { continue }
                    $existingKey = @($properties.Keys | Where-Object { $_ -ieq $requestedAttribute } | Select-Object -First 1)
                    if ($existingKey.Count -eq 0) {
                        $properties[$requestedAttribute] = $null
                    }
                }
                [PSCustomObject]$properties
            }
        }
    }

    It 'returns a valid empty posture when no policies or silos exist' {
        $result = Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $result.PolicyCount | Should -Be 0
        $result.SiloCount | Should -Be 0
        $result.MissingRequiredAttributeCount | Should -Be 0
    }

    It 'preserves omitted attributes after production-style normalization' {
        $script:SearchResults['(objectClass=msDS-AuthNPolicy)'] = [PSCustomObject]@{
            Name = 'Policy with omitted expression attributes'
            DistinguishedName = 'CN=Policy with omitted expression attributes,CN=AuthN Policies,CN=AuthN Policy Configuration,CN=Services,CN=Configuration,DC=contoso,DC=com'
            'msDS-AuthNPolicyEnforced' = $false
        }
        $result = Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $result.Policies[0].AttributeState.'msDS-ComputerAllowedToAuthenticateTo'.Present | Should -BeFalse
        $result.Policies[0].AttributeState.'msDS-ComputerAllowedToAuthenticateTo'.IsNull | Should -BeFalse
        $result.MissingRequiredAttributeCount | Should -Be 5
    }
    It 'distinguishes a missing requested attribute from a configured empty value' {
        $script:SearchResults['(objectClass=msDS-AuthNPolicy)'] = [PSCustomObject]@{
            Name = 'Tier0 Policy'
            DistinguishedName = 'CN=Tier0 Policy,CN=AuthN Policies,CN=AuthN Policy Configuration,CN=Services,CN=Configuration,DC=contoso,DC=com'
            'msDS-AuthNPolicyEnforced' = $true
            'msDS-UserAllowedToAuthenticateFrom' = ''
            'msDS-UserAllowedToAuthenticateTo' = '(@USER.ad://ext/AuthenticationSilo == "Tier0")'
            'msDS-ServiceAllowedToAuthenticateFrom' = $null
            'msDS-ServiceAllowedToAuthenticateTo' = $null
        }
        $result = Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $result.PolicyCount | Should -Be 1
        $result.EnforcedPolicyCount | Should -Be 1
        $result.MissingRequiredAttributeCount | Should -Be 1
        $result.Policies[0].AttributeState.'msDS-UserAllowedToAuthenticateFrom'.IsEmpty | Should -BeTrue
        $result.Policies[0].AttributeState.'msDS-ComputerAllowedToAuthenticateTo'.Present | Should -BeFalse
    }

    It 'reports enforced silo posture and preserves members' {
        $script:SearchResults['(objectClass=msDS-AuthNPolicySilo)'] = [PSCustomObject]@{
            Name = 'Tier0 Silo'
            DistinguishedName = 'CN=Tier0 Silo,CN=AuthN Silos,CN=AuthN Policy Configuration,CN=Services,CN=Configuration,DC=contoso,DC=com'
            'msDS-AuthNPolicySiloEnforced' = $true
            'msDS-AuthNPolicySiloMembers' = @('CN=Admin One,OU=Admins,DC=contoso,DC=com')
        }
        $result = Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $result.SiloCount | Should -Be 1
        $result.EnforcedSiloCount | Should -Be 1
        # Wrap the member value because PowerShell unwraps a single-item array during property access.
        @($result.Silos[0].Members).Count | Should -Be 1
    }

    It 'produces a state object suitable for the OrderedDictionary domain-state contract' {
        $state = Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $domainState = [ordered]@{ AuthenticationPolicyState = $state }
        $domainState['AuthenticationPolicyState'].PolicyCount | Should -Be 0
        $domainState['AuthenticationPolicyState'].MissingRequiredAttributeCount | Should -Be 0
    }
    It 'normalizes LDAP string Boolean enforcement values' {
        $script:SearchResults['(objectClass=msDS-AuthNPolicy)'] = @(
            [PSCustomObject]@{ Name='Audit Policy'; DistinguishedName='CN=Audit Policy,CN=Configuration,DC=contoso,DC=com'; 'msDS-AuthNPolicyEnforced'='FALSE' },
            [PSCustomObject]@{ Name='Enforced Policy'; DistinguishedName='CN=Enforced Policy,CN=Configuration,DC=contoso,DC=com'; 'msDS-AuthNPolicyEnforced'='TRUE' }
        )
        $script:SearchResults['(objectClass=msDS-AuthNPolicySilo)'] = @(
            [PSCustomObject]@{ Name='Audit Silo'; DistinguishedName='CN=Audit Silo,CN=Configuration,DC=contoso,DC=com'; 'msDS-AuthNPolicySiloEnforced'='0' },
            [PSCustomObject]@{ Name='Enforced Silo'; DistinguishedName='CN=Enforced Silo,CN=Configuration,DC=contoso,DC=com'; 'msDS-AuthNPolicySiloEnforced'='1' }
        )
        $result = Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $result.EnforcedPolicyCount | Should -Be 1
        $result.EnforcedSiloCount | Should -Be 1
        $result.Policies[0].Enforced | Should -BeFalse
        $result.Policies[1].Enforced | Should -BeTrue
        $result.Silos[0].Enforced | Should -BeFalse
        $result.Silos[1].Enforced | Should -BeTrue
    }
}
