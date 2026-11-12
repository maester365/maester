BeforeAll { Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force }
Describe 'gMSA managed-password authorization source contract' {
    It 'never requests or decodes the managed password value' {
        $source=Get-Content "$PSScriptRoot/../../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Not -Match '(?i)[''"]msDS-ManagedPassword[''"]'
        $source | Should -Not -Match 'ConvertFrom-.*ManagedPassword|kinit|New-PSSession|Get-Credential|Invoke-Command'
        $source | Should -Match 'msDS-GroupMSAMembership'
    }
    It 'requires an applicable retrieval access mask' {
        $source=Get-Content "$PSScriptRoot/../../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Match 'rightDsReadProperty'
        $source | Should -Match 'genericRead'
        $source | Should -Match 'genericAll'
        $source | Should -Match 'Test-MtGmsaPasswordRetrievalAccessMask'
    }
    It 'recognizes broad domain and builtin groups' {
        $source=Get-Content "$PSScriptRoot/../../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Match 'S-1-5-32-545'
        $source | Should -Match '-513\$'
        $source | Should -Match '-515\$'
        $source | Should -Match 'Get-MtGmsaBroadPrincipalName'
    }
    It 'records explicit resolution and evidence status values' {
        $source=Get-Content "$PSScriptRoot/../../../internal/services/ad/queries/Get-MtLdapServiceAccount.ps1" -Raw
        $source | Should -Match 'ResolutionStatus'
        $source | Should -Match 'AuthorizationDescriptorAbsent'
        $source | Should -Match 'AuthorizationDescriptorEmpty'
        $source | Should -Match 'AuthorizationDescriptorParseFailure'
        $source | Should -Match 'AuthorizationDescriptorUnsupportedShape'
    }
    It 'uses registered taxonomy and High severity for AD-MSA-02' {
        $test02=Get-Content "$PSScriptRoot/../../../../tests/ad/security/Test.AD-MSA-02.ps1" -Raw
        $test03=Get-Content "$PSScriptRoot/../../../../tests/ad/security/Test.AD-MSA-03.ps1" -Raw
foreach($testSource in @($test02,$test03)){$testSource|Should -Match "Feature='account-security'";$testSource|Should -Match "ResourceType='Computer'"}
$test02 | Should -Match "Area='applications'"
$test03 | Should -Match "Area='applications'"
        $test02 | Should -Match "Severity='High'"
    }
    It 'does not permit a clean pass when ServiceAccounts state is unavailable' {
        foreach($path in @("$PSScriptRoot/../../../../tests/ad/security/Test.AD-MSA-02.ps1","$PSScriptRoot/../../../../tests/ad/security/Test.AD-MSA-03.ps1")){(Get-Content $path -Raw)|Should -Match '\$null -eq \$state\.ServiceAccounts'}
    }
    It 'reports unresolved SID resolution details' {
        $source=Get-Content "$PSScriptRoot/../../../../tests/ad/security/Test.AD-MSA-03.ps1" -Raw
        $source|Should -Match 'ResolutionStatus';$source|Should -Match 'ResolutionError';$source|Should -Match '\$trustee\.Sid'
    }
    It 'classifies signed GENERIC_READ through the collector and rejects READ_CONTROL-only ACEs' {
        InModuleScope Maester {
            $connection = [Runtime.Serialization.FormatterServices]::GetUninitializedObject(
                [System.DirectoryServices.Protocols.LdapConnection]
            )

            Mock Invoke-MtLdapSearch {
                [pscustomobject]@{
                    DistinguishedName = 'CN=svc-web,CN=Managed Service Accounts,DC=contoso,DC=com'
                    name = 'svc-web'
                    sAMAccountName = 'svc-web$'
                    dNSHostName = 'svc-web.contoso.com'
                    objectSid = 'S-1-5-21-1-2-3-1101'
                    'msDS-GroupMSAMembership' = [byte[]](1, 2, 3, 4)
                }
            } -ParameterFilter {
                $Filter -eq '(objectClass=msDS-GroupManagedServiceAccount)'
            }

            Mock ConvertFrom-MtLdapSecurityDescriptor {
                [pscustomobject]@{
                    Access = @(
                        [pscustomobject]@{
                            AccessControlType = 'Allow'
                            AccessMask = -2147483648
                            Sid = 'S-1-5-32-545'
                            IdentityReference = 'BUILTIN\Users'
                            IsInherited = $false
                        }
                        [pscustomobject]@{
                            AccessControlType = 'Allow'
                            AccessMask = 131072
                            Sid = 'S-1-5-11'
                            IdentityReference = 'NT AUTHORITY\Authenticated Users'
                            IsInherited = $false
                        }
                    )
                }
            }

            $result = @(
                Get-MtLdapServiceAccount `
                    -Connection $connection `
                    -SearchBase 'DC=contoso,DC=com'
            )

            $result.Count | Should -Be 1
            $result[0].PasswordRetrievalTrustees.Count | Should -Be 1
            $result[0].BroadPasswordRetrievalTrustees.Count | Should -Be 1

            $trustee = $result[0].BroadPasswordRetrievalTrustees[0]
            $trustee.Sid | Should -Be 'S-1-5-32-545'
            $trustee.Classification | Should -Be 'Broad'
            $trustee.BroadPrincipalName | Should -Be 'BUILTIN\Users'
            $result[0].PasswordRetrievalTrustees.Sid | Should -Not -Contain 'S-1-5-11'
        }
    }
}
