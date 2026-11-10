BeforeAll { Import-Module "$PSScriptRoot/../../Maester.psd1" -Force }
Describe 'gMSA managed-password authorization source contract' {
    It 'never requests the managed password value' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Not -Match '(?i)[''"]msDS-ManagedPassword[''"]'
        $source | Should -Match 'msDS-GroupMSAMembership'
    }
    It 'does not contain credential-use operations' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Not -Match 'ConvertFrom-.*ManagedPassword|kinit|New-PSSession|Get-Credential|Invoke-Command'
    }
    It 'resolves authorization SIDs through LDAP and records resolution status' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Match 'ConvertTo-MtGmsaSidFilterValue'
        $source | Should -Match 'ResolutionStatus'
        $source | Should -Match 'NestedExpansionStatus'
        $source | Should -Match 'sidResolutionCache'
        $source | Should -Match 'function ConvertTo-MtGmsaSidFilterValue'
        $source | Should -Not -Match 'ConvertTo-SidFilterValue -Sid'
    }
    It 'records explicit authorization evidence status values' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Match 'AuthorizationDescriptorAbsent'
        $source | Should -Match 'AuthorizationDescriptorEmpty'
        $source | Should -Match 'AuthorizationDescriptorParseFailure'
        $source | Should -Match 'AuthorizationDescriptorUnsupportedShape'
    }
    It 'uses registered Maester taxonomy values' {
        foreach($testPath in @(
            "$PSScriptRoot/../../../tests/ad/security/Test.AD-MSA-02.ps1",
            "$PSScriptRoot/../../../tests/ad/security/Test.AD-MSA-03.ps1"
        )) {
            $testSource=Get-Content $testPath -Raw
            $testSource | Should -Match "Feature='account-security'"
            $testSource | Should -Match "Area='privileged-access'"
            $testSource | Should -Match "ResourceType='Computer'"
        }
    }
}