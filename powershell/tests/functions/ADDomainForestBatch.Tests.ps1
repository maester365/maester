BeforeAll {
    . "$PSScriptRoot/../../internal/checks/ad/ad/Get-MtAdDomainControllerRelease.ps1"
    . "$PSScriptRoot/../../internal/checks/ad/ad/Get-MtAdFunctionalLevelAssessment.ps1"
    . "$PSScriptRoot/../../internal/checks/ad/ad/Get-MtAdDomainControllersInScope.ps1"
    . "$PSScriptRoot/../../internal/checks/ad/ad/Get-MtAdDomainNameFindings.ps1"
    . "$PSScriptRoot/../../internal/checks/ad/ad/Get-MtAdFsmoPlacement.ps1"
}

Describe 'Native AD domain and forest results' {
    BeforeAll { Import-Module "$PSScriptRoot/../../Maester.psd1" -Force }
    BeforeEach {
        $script:batchDetail = $null
        $script:batchState = [pscustomobject]@{
            Domain = [pscustomobject]@{
                DistinguishedName = 'DC=example,DC=com'; DnsRoot = 'example.com'; DomainLevelValue = 10
            }
            Forest = [pscustomobject]@{
                ForestLevelValue = 10; Domains = @('example.com', 'child.example.com')
            }
            DomainControllers = @([pscustomobject]@{
                Name = 'root'; DnsHostName = 'root.example.com'
                ServerReference = 'CN=root,CN=Domain Controllers,DC=example,DC=com'
                OperatingSystem = 'Windows Server 2025'; OperatingSystemVersion = '10.0 (26100)'
                SupportedLevelValue = 10; IsGlobalCatalog = $true
            })
        }
        Mock -ModuleName Maester Get-MtADDomainState { $script:batchState }
        Mock -ModuleName Maester Add-MtTestResultDetail { $script:batchDetail = $Result; return }
    }

    It 'excludes other-domain DCs and fails DOM-01 and FOR-01 only on incompatible connected-domain support' {
        $script:batchState.DomainControllers += [pscustomobject]@{
            Name = 'child'; DnsHostName = 'child.child.example.com'
            ServerReference = 'CN=child,CN=Domain Controllers,DC=child,DC=example,DC=com'
            OperatingSystem = 'Windows Server 2022'; OperatingSystemVersion = '10.0 (20348)'
            SupportedLevelValue = 7; IsGlobalCatalog = $true
        }
        InModuleScope Maester { Test-MtAdForestFunctionalLevel | Should -BeTrue }
        $script:batchDetail | Should -Match '\| Other-domain DCs excluded \| 1 \|'
        $script:batchState.DomainControllers.Count | Should -Be 2
        $script:batchState.DomainControllers[1].ServerReference = 'CN=child,CN=Domain Controllers,DC=example,DC=com'
        InModuleScope Maester {
            Test-MtAdDomainFunctionalLevel | Should -BeFalse
            Test-MtAdForestFunctionalLevel | Should -BeFalse
        }
        $script:batchDetail | Should -Match 'exceeds connected-domain DC support'
        $script:batchState.Domain.DomainLevelValue = 7
        $script:batchState.Forest.ForestLevelValue = 7
        InModuleScope Maester {
            Test-MtAdDomainFunctionalLevel | Should -BeTrue
            Test-MtAdForestFunctionalLevel | Should -BeTrue
        }
    }

    It 'counts only connected-domain DCs even when child DNS names have the parent suffix' {
        $script:batchState.DomainControllers += [pscustomobject]@{
            Name = 'child'; DnsHostName = 'child.child.example.com'
            ServerReference = 'CN=child,CN=Domain Controllers,DC=child,DC=example,DC=com'
        }
        InModuleScope Maester { Test-MtAdDomainControllerCount }
        $script:batchDetail | Should -Match 'has 1 inventoried DC'
        $script:batchDetail | Should -Not -Match 'child'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'excludes foreign-domain lookup errors but rejects unknown connected-domain OS metadata' {
        $script:batchState.DomainControllers += [pscustomobject]@{
            Name = 'foreign'; DnsHostName = 'foreign.child.example.com'
            ServerReference = 'CN=foreign,CN=Domain Controllers,DC=child,DC=example,DC=com'
            OperatingSystem = $null; OperatingSystemVersion = $null
            CollectionError = 'Foreign computer lookup failed'
        }
        InModuleScope Maester {
            Test-MtAdDcOperatingSystemCount | Should -BeTrue
            Test-MtAdForestFunctionalLevel | Should -BeTrue
        }
        $script:batchDetail | Should -Match '\| Other-domain DCs excluded \| 1 \|'
        $script:batchState.DomainControllers[1].ServerReference = 'CN=foreign,CN=Domain Controllers,DC=example,DC=com'
        InModuleScope Maester {
            { Test-MtAdDcOperatingSystemCount } | Should -Throw '*foreign*'
            { Test-MtAdForestFunctionalLevel } | Should -Throw '*foreign*'
        }
    }

    It 'decodes the live RID Manager pool without casting a signed hexadecimal mask' {
        $script:batchState.Domain | Add-Member -NotePropertyName RIDAvailablePool -NotePropertyValue '4611686014132428208'
        InModuleScope Maester { Test-MtAdRidsRemaining }
        $script:batchDetail | Should -Match '\| RID Manager pool upper bound \| 1073741823 \|'
        $script:batchDetail | Should -Match '\| Next allocation boundary \| 7600 \|'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'renders quota values as separate metric rows without changing the baseline' {
        $script:batchState.Domain | Add-Member -NotePropertyName MsDsMachineAccountQuota -NotePropertyValue 0
        InModuleScope Maester { Test-MtAdMachineAccountQuota | Should -BeTrue }
        $script:batchDetail | Should -Match '\| Matches documented default \| False \|'
        $script:batchState.Domain.MsDsMachineAccountQuota = 10
        InModuleScope Maester { Test-MtAdMachineAccountQuota | Should -BeFalse }
        $script:batchDetail | Should -Match '\| Observed ms-DS-MachineAccountQuota \| 10 \|'
    }

    It 'fails when there is no GC, passes with one GC, and errors when status is unknown' {
        $script:batchState.DomainControllers[0].IsGlobalCatalog = $false
        InModuleScope Maester { Test-MtAdDcNonGlobalCatalogCount | Should -BeFalse }
        $script:batchDetail | Should -Match '\| Non-Global Catalog DCs \| 1 \|'
        $script:batchState.DomainControllers[0].IsGlobalCatalog = $true
        InModuleScope Maester { Test-MtAdDcNonGlobalCatalogCount | Should -BeTrue }
        $script:batchState.DomainControllers[0].IsGlobalCatalog = $null
        InModuleScope Maester { { Test-MtAdDcNonGlobalCatalogCount } | Should -Throw '*Incomplete GC status*' }
    }

    It 'shows both LDAP and LDAPS unknown ports without claiming live listener evidence' {
        $script:batchState.DomainControllers[0] | Add-Member -NotePropertyName LdapPort -NotePropertyValue $null
        $script:batchState.DomainControllers[0] | Add-Member -NotePropertyName SslPort -NotePropertyValue $null
        $script:batchState.DomainControllers[0] | Add-Member -NotePropertyName PortEvidence -NotePropertyValue 'Not measured'
        InModuleScope Maester { Test-MtAdDcNonStandardLdapPortCount }
        $script:batchDetail | Should -Match '\| LDAP \| 389 \| 0 \| 1 \| 0 \|'
        $script:batchDetail | Should -Match '\| LDAPS \| 636 \| 0 \| 1 \| 0 \|'
        $script:batchDetail | Should -Match '\| root.example.com \| Unknown \| Unknown \| Not measured \|'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'reports forest partition DNS and NetBIOS syntax findings in survivor check tables' {
        $script:batchState.Forest | Add-Member -NotePropertyName DomainPartitions -NotePropertyValue @(
            [pscustomobject]@{ DistinguishedName = 'DC=example,DC=com'; DnsRoot = 'example.com'; NetBIOSName = 'EXAMPLE' },
            [pscustomobject]@{ DistinguishedName = 'DC=bad,DC=example,DC=com'; DnsRoot = 'bad..example.com'; NetBIOSName = 'BAD/NAME' }
        )
        InModuleScope Maester { Test-MtAdDomainNameStandardCompliance | Should -BeFalse }
        $script:batchDetail | Should -Match '\| bad\.\.example\.com \| Invalid \|'
        InModuleScope Maester { Test-MtAdNetbiosNameStandardCompliance | Should -BeFalse }
        $script:batchDetail | Should -Match '\| BAD/NAME \| Invalid \|'
    }

    It 'lists every FSMO owner as a DN and counts distinct holders in DC-05' {
        $root = 'DC=example,DC=com'
        $owner = "CN=NTDS Settings,CN=ROOT,CN=Servers,CN=Site,CN=Sites,CN=Configuration,$root"
        $script:batchState.Forest | Add-Member -NotePropertyName RootDomain -NotePropertyValue 'example.com'
        $script:batchState.Forest | Add-Member -NotePropertyName RootDomainDistinguishedName -NotePropertyValue $root
        $script:batchState.Forest | Add-Member -NotePropertyName SchemaOwnerDistinguishedName -NotePropertyValue $owner
        $script:batchState.Forest | Add-Member -NotePropertyName DomainNamingOwnerDistinguishedName -NotePropertyValue $owner
        $script:batchState.Domain | Add-Member -NotePropertyName PdcOwnerDistinguishedName -NotePropertyValue $owner
        $script:batchState.Domain | Add-Member -NotePropertyName RidOwnerDistinguishedName -NotePropertyValue $owner
        $script:batchState.Domain | Add-Member -NotePropertyName InfrastructureOwnerDistinguishedName -NotePropertyValue $owner
        $script:batchState.DomainControllers[0] | Add-Member -NotePropertyName DistinguishedName -NotePropertyValue $owner
        $script:batchState.DomainControllers[0] | Add-Member -NotePropertyName IsReadOnly -NotePropertyValue $false
        InModuleScope Maester { Test-MtAdDcAllFsmoRolesCount | Should -BeTrue }
        $script:batchDetail | Should -Match '\| Distinct owner DNs \| 1 \|'
        $script:batchDetail | Should -Match '\| Schema \| CN=NTDS Settings'
        $script:batchDetail | Should -Match '\| Infrastructure \| CN=NTDS Settings'
        $otherOwner = "CN=NTDS Settings,CN=OTHER,CN=Servers,CN=Site,CN=Sites,CN=Configuration,$root"
        $script:batchState.DomainControllers += [pscustomobject]@{
            DistinguishedName = $otherOwner
            ServerReference = "CN=OTHER,OU=Domain Controllers,$root"
            IsReadOnly = $false
            IsGlobalCatalog = $true
        }
        $script:batchState.Domain.RidOwnerDistinguishedName = $otherOwner
        InModuleScope Maester { Test-MtAdDcAllFsmoRolesCount | Should -BeFalse }
        $script:batchDetail | Should -Match '(?m)^- RID Master is not on the connected domain PDC\.'
    }
}

Describe 'AD domain and forest assessments' {
    It 'supports functional level 10 only with all Server 2025 DCs' {
        $controllers = @(
            [pscustomobject]@{ Name = 'new'; OperatingSystem = 'Windows Server 2025'; OperatingSystemVersion = '10.0 (26100)'; SupportedLevelValue = 10 },
            [pscustomobject]@{ Name = 'old'; OperatingSystem = 'Windows Server 2022'; OperatingSystemVersion = '10.0 (20348)'; SupportedLevelValue = 7 }
        )
        $state = [pscustomobject]@{ Forest = [pscustomobject]@{ ForestLevelValue = 7 }; DomainControllers = $controllers }
        (Get-MtAdFunctionalLevelAssessment -State $state -Scope Forest).Target | Should -Be 7
        $state.DomainControllers = @($controllers[0])
        (Get-MtAdFunctionalLevelAssessment -State $state -Scope Forest).Target | Should -Be 10
    }

    It 'errors on a foreign DC with unknown OS metadata rather than passing' {
        $state = [pscustomobject]@{ Forest = [pscustomobject]@{ ForestLevelValue = 7 }; DomainControllers = @([pscustomobject]@{ Name = 'foreign'; CollectionError = 'Computer lookup failed'; OperatingSystem = $null }) }
        { Get-MtAdFunctionalLevelAssessment -State $state -Scope Forest } | Should -Throw '*foreign*'
    }

    It 'scopes domain controller count to the connected domain, not forest DNS suffixes' {
        $state = [pscustomobject]@{
            Domain = [pscustomobject]@{ DistinguishedName = 'DC=example,DC=com'; DnsRoot = 'example.com' }
            DomainControllers = @(
                [pscustomobject]@{ Name = 'connected'; ServerReference = 'CN=dc,CN=Domain Controllers,DC=example,DC=com' },
                [pscustomobject]@{ Name = 'foreign'; ServerReference = 'CN=dc,CN=Domain Controllers,DC=child,DC=example,DC=com' }
            )
        }
        @(Get-MtAdDomainControllersInScope -State $state).Name | Should -Be 'connected'
    }

    It 'treats absent forest domain partition metadata as an error' {
        { Get-MtAdDomainNameFindings -Forest ([pscustomobject]@{ Domains = @('example.com') }) -Kind Dns } | Should -Throw '*partition*'
    }

    It 'validates Unicode DNS labels through IDNA and checks NetBIOS names separately' {
        $forest = [pscustomobject]@{ Domains = @('xn--bcher-kva.example'); DomainPartitions = @([pscustomobject]@{ DistinguishedName = 'DC=x,DC=example'; DnsRoot = 'bücher.example'; NetBIOSName = 'BÜCHER' }) }
        @(Get-MtAdDomainNameFindings -Forest $forest -Kind Dns).Count | Should -Be 0
        @(Get-MtAdDomainNameFindings -Forest $forest -Kind Netbios).Count | Should -Be 0
    }

    It 'compares FSMO owners as NTDS DNs, not resolved hostnames' {
        $root = 'DC=example,DC=com'
        $owner = "CN=NTDS Settings,CN=DC1,CN=Servers,CN=Site,CN=Sites,CN=Configuration,$root"
        $dc = [pscustomobject]@{ DistinguishedName = $owner; ServerReference = 'CN=DC1,OU=DCs,DC=example,DC=com'; Name = 'DC1'; IsReadOnly = $false; IsGlobalCatalog = $true }
        $state = [pscustomobject]@{
            Forest = [pscustomobject]@{ RootDomain = 'example.com'; RootDomainDistinguishedName = $root; Domains = @('example.com'); SchemaOwnerDistinguishedName = $owner; DomainNamingOwnerDistinguishedName = $owner }
            Domain = [pscustomobject]@{ DistinguishedName = $root; PdcOwnerDistinguishedName = $owner; RidOwnerDistinguishedName = $owner; InfrastructureOwnerDistinguishedName = $owner }
            DomainControllers = @($dc)
        }
        (Get-MtAdFsmoPlacement -State $state).Issues.Count | Should -Be 0
        $state.Domain.RidOwnerDistinguishedName = 'DC1.example.com'
        { Get-MtAdFsmoPlacement -State $state } | Should -Throw '*NTDS Settings DN*'
    }

    It 'requires non-GC Infrastructure Master only for the multi-domain, non-all-GC, Recycle Bin disabled case' {
        $root = 'DC=example,DC=com'
        $owner = "CN=NTDS Settings,CN=DC1,CN=Servers,CN=Site,CN=Sites,CN=Configuration,$root"
        $other = "CN=NTDS Settings,CN=DC2,CN=Servers,CN=Site,CN=Sites,CN=Configuration,$root"
        $dc1 = [pscustomobject]@{ DistinguishedName = $owner; ServerReference = 'CN=DC1,OU=DCs,DC=example,DC=com'; IsReadOnly = $false; IsGlobalCatalog = $true }
        $dc2 = [pscustomobject]@{ DistinguishedName = $other; ServerReference = 'CN=DC2,OU=DCs,DC=example,DC=com'; IsReadOnly = $false; IsGlobalCatalog = $false }
        $state = [pscustomobject]@{
            Forest = [pscustomobject]@{ RootDomain = 'example.com'; RootDomainDistinguishedName = $root; Domains = @('example.com', 'child.example.com'); SchemaOwnerDistinguishedName = $owner; DomainNamingOwnerDistinguishedName = $owner }
            Domain = [pscustomobject]@{ DistinguishedName = $root; PdcOwnerDistinguishedName = $owner; RidOwnerDistinguishedName = $owner; InfrastructureOwnerDistinguishedName = $owner }
            DomainControllers = @($dc1, $dc2)
            OptionalFeatures = @([pscustomobject]@{ Name = 'Recycle Bin Feature'; IsEnabled = $false })
        }
        (Get-MtAdFsmoPlacement -State $state).Issues -join ' ' | Should -Match 'Infrastructure Master is a GC'
        $state.OptionalFeatures[0].IsEnabled = $true
        @( (Get-MtAdFsmoPlacement -State $state).Issues ).Count | Should -Be 0
        $state.OptionalFeatures[0].IsEnabled = $false
        $dc2.IsGlobalCatalog = $true
        @( (Get-MtAdFsmoPlacement -State $state).Issues ).Count | Should -Be 0
    }
    It 'classifies Server 2012 R2 as known legacy and preserves its supported level' {
        $dc = [pscustomobject]@{ Name = 'legacy'; OperatingSystem = 'Windows Server 2012 R2'; OperatingSystemVersion = '6.3 (9600)'; SupportedLevelValue = 6 }
        (Get-MtAdDomainControllerRelease -Controller $dc) | Should -Be 2012
        $state = [pscustomobject]@{ Forest = [pscustomobject]@{ ForestLevelValue = 6 }; DomainControllers = @($dc) }
        (Get-MtAdFunctionalLevelAssessment -State $state -Scope Forest).Target | Should -Be 6
    }
}
