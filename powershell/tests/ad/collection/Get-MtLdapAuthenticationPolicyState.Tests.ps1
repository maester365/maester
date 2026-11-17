BeforeAll {
    . (Join-Path $PSScriptRoot '../../../internal/services/ad/Get-MtLdapAuthenticationPolicyState.ps1')
}
Describe 'Get-MtLdapAuthenticationPolicyState' {
    BeforeEach {
        $script:SearchResults = @{}
        function Invoke-MtLdapSearch {
            param($Connection,$SearchBase,$Scope,$Filter,$Attributes)
            foreach ($sourceItem in @($script:SearchResults[$Filter])) {
                if ($null -eq $sourceItem) { continue }
                $properties = [ordered]@{}
                foreach ($property in $sourceItem.PSObject.Properties) { $properties[$property.Name] = $property.Value }
                foreach ($requestedAttribute in @($Attributes)) {
                    if ($requestedAttribute -in @('*','+','1.1','distinguishedName')) { continue }
                    if (@($properties.Keys | Where-Object { $_ -ieq $requestedAttribute }).Count -eq 0) { $properties[$requestedAttribute] = $null }
                }
                [PSCustomObject]$properties
            }
        }
    }
    It 'returns a valid empty posture' {
        $result=Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $result.PolicyCount | Should -Be 0
        $result.SiloCount | Should -Be 0
        $result.NonEnforcedSilos | Should -BeNullOrEmpty
    }
    It 'treats omitted optional expression attributes as null without classifying collection failure' {
        $script:SearchResults['(objectClass=msDS-AuthNPolicy)']=[PSCustomObject]@{ Name='Policy'; DistinguishedName='CN=Policy,CN=Configuration,DC=contoso,DC=com'; 'msDS-AuthNPolicyEnforced'=$true }
        $result=Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $result.PolicyCount | Should -Be 1
        $result.Policies[0].ComputerAllowedToAuthenticateTo | Should -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Not -Contain 'MissingRequiredAttributeCount'
        $result.Policies[0].PSObject.Properties.Name | Should -Not -Contain 'AttributeState'
    }
    It 'normalizes LDAP string Boolean enforcement values' {
        $script:SearchResults['(objectClass=msDS-AuthNPolicy)']=@(
            [PSCustomObject]@{Name='Audit';DistinguishedName='CN=Audit';'msDS-AuthNPolicyEnforced'='FALSE'},
            [PSCustomObject]@{Name='Enforced';DistinguishedName='CN=Enforced';'msDS-AuthNPolicyEnforced'='TRUE'})
        $script:SearchResults['(objectClass=msDS-AuthNPolicySilo)']=@(
            [PSCustomObject]@{Name='Audit Silo';DistinguishedName='CN=Audit Silo';'msDS-AuthNPolicySiloEnforced'='0'},
            [PSCustomObject]@{Name='Enforced Silo';DistinguishedName='CN=Enforced Silo';'msDS-AuthNPolicySiloEnforced'='1'})
        $result=Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $result.EnforcedPolicyCount | Should -Be 1
        $result.EnforcedSiloCount | Should -Be 1
        $result.NonEnforcedSilos | Should -Contain 'Audit Silo'
    }
    It 'preserves silo members and policy assignments' {
        $script:SearchResults['(objectClass=msDS-AuthNPolicySilo)']=[PSCustomObject]@{Name='Tier0 Silo';DistinguishedName='CN=Tier0 Silo';'msDS-AuthNPolicySiloEnforced'=$true;'msDS-UserAuthNPolicy'='CN=User Policy';'msDS-AuthNPolicySiloMembers'=@('CN=Admin One')}
        $result=Get-MtLdapAuthenticationPolicyState -Connection ([PSCustomObject]@{}) -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
        $result.Silos[0].UserAuthNPolicy | Should -Be 'CN=User Policy'
        @($result.Silos[0].Members).Count | Should -Be 1
    }
}
