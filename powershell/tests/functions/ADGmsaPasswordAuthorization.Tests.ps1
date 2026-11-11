BeforeAll { Import-Module "$PSScriptRoot/../../Maester.psd1" -Force }
Describe 'gMSA managed-password authorization source contract' {
    It 'never requests or decodes the managed password value' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Not -Match '(?i)[''"]msDS-ManagedPassword[''"]'
        $source | Should -Not -Match 'ConvertFrom-.*ManagedPassword|kinit|New-PSSession|Get-Credential|Invoke-Command'
        $source | Should -Match 'msDS-GroupMSAMembership'
    }
    It 'requires an applicable retrieval access mask' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Match 'rightDsReadProperty'
        $source | Should -Match 'genericRead'
        $source | Should -Match 'genericAll'
        $source | Should -Match 'Test-MtGmsaPasswordRetrievalAccessMask'
    }
    It 'recognizes broad domain and builtin groups' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Match 'S-1-5-32-545'
        $source | Should -Match '-513\$'
        $source | Should -Match '-515\$'
        $source | Should -Match 'Get-MtGmsaBroadPrincipalName'
    }
    It 'records explicit resolution and evidence status values' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Match 'ResolutionStatus'
        $source | Should -Match 'AuthorizationDescriptorAbsent'
        $source | Should -Match 'AuthorizationDescriptorEmpty'
        $source | Should -Match 'AuthorizationDescriptorParseFailure'
        $source | Should -Match 'AuthorizationDescriptorUnsupportedShape'
    }
    It 'uses registered taxonomy and Medium severity for AD-MSA-02' {
        $test02=Get-Content "$PSScriptRoot/../../../tests/ad/security/Test.AD-MSA-02.ps1" -Raw
        $test03=Get-Content "$PSScriptRoot/../../../tests/ad/security/Test.AD-MSA-03.ps1" -Raw
foreach($testSource in @($test02,$test03)){$testSource|Should -Match "Feature='account-security'";$testSource|Should -Match "ResourceType='Computer'"}
$test02 | Should -Match "Area='applications'"
$test03 | Should -Match "Area='privileged-access'"
        $test02 | Should -Match "Severity='Medium'"
    }
    It 'does not permit a clean pass when ServiceAccounts state is unavailable' {
        foreach($path in @("$PSScriptRoot/../../../tests/ad/security/Test.AD-MSA-02.ps1","$PSScriptRoot/../../../tests/ad/security/Test.AD-MSA-03.ps1")){(Get-Content $path -Raw)|Should -Match '\$null -eq \$state\.ServiceAccounts'}
    }
    It 'reports unresolved SID resolution details' {
        $source=Get-Content "$PSScriptRoot/../../../tests/ad/security/Test.AD-MSA-03.ps1" -Raw
        $source|Should -Match 'ResolutionStatus';$source|Should -Match 'ResolutionError';$source|Should -Match '\$trustee\.Sid'
    }
    It 'normalizes the signed GENERIC_READ access mask' {
        $signedGenericRead = -2147483648
        $normalizedMask = [int64]$signedGenericRead

        if ($normalizedMask -lt 0) {
            $normalizedMask += 4294967296L
        }

        [uint32]$normalizedMask | Should -Be ([uint32]2147483648)
        ('{0:X8}' -f [uint32]$normalizedMask) | Should -Be '80000000'
    }
}
