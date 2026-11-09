BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'AD second-batch collector contracts' {
    BeforeEach {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection { }
        Mock -ModuleName Maester Get-MtLdapRootDse -RemoveParameterType Connection {
            [pscustomobject]@{ DefaultNamingContext = 'DC=example,DC=com'; RootDomainNamingContext = 'DC=example,DC=com'; ConfigurationNamingContext = 'CN=Configuration,DC=example,DC=com'; ForestFunctionality = 10 }
        }
    }

    It 'normalizes AD interval sentinels without conflating their meanings' {
        InModuleScope Maester {
            (ConvertFrom-MtLdapValue -Value ([long]::MinValue.ToString()) -AttributeName 'maxPwdAge') | Should -Be ([timespan]::Zero)
            (ConvertFrom-MtLdapValue -Value '-9000000000' -AttributeName 'lockOutObservationWindow') | Should -Be ([timespan]::FromMinutes(15))
            (ConvertFrom-MtLdapValue -Value '-9000000000' -AttributeName 'msDS-LockoutObservationWindow') | Should -Be ([timespan]::FromMinutes(15))
            (ConvertFrom-MtLdapValue -Value 'FALSE' -AttributeName 'msDS-PasswordReversibleEncryptionEnabled') | Should -BeFalse
        }
    }

    It 'keeps PSO complexity and reversible encryption as separate booleans' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{
                name = 'PSO'; DistinguishedName = 'CN=PSO,DC=example,DC=com'
                'msDS-PasswordComplexityEnabled' = $false; 'msDS-PasswordReversibleEncryptionEnabled' = $true
                'msDS-MaximumPasswordAge' = [timespan]::Zero; 'msDS-LockoutDuration' = [timespan]::Zero
                'msDS-LockoutObservationWindow' = [timespan]::FromMinutes(15)
            }
        }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $pso = @(Get-MtLdapFineGrainedPasswordPolicy -Connection $connection -SearchBase 'DC=example,DC=com')[0]
                $pso.ComplexityEnabled | Should -BeFalse
                $pso.ReversibleEncryptionEnabled | Should -BeTrue
                $pso.PasswordExpirationDisabled | Should -BeTrue
                $pso.LockoutRequiresAdminUnlock | Should -BeTrue
                $pso.LockoutObservationWindow | Should -Be ([timespan]::FromMinutes(15))
            }
            finally { $connection.Dispose() }
        }
    }

    It 'collects protected krbtgt markers and resultant policy without password secrets' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{
                name = 'RODC key'; sAMAccountName = 'krbtgt_1234'; userAccountControl = 514
                'msDS-SecondaryKrbTgtNumber' = 1234; 'msDS-KrbTgtLinkBL' = @('CN=RODC,DC=example,DC=com')
                'msDS-ResultantPSO' = 'CN=PSO,DC=example,DC=com'
            }
        }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $user = @(Get-MtLdapUser -Connection $connection -SearchBase 'DC=example,DC=com')[0]
                $user.SecondaryKrbtgtNumber | Should -Be 1234
                $user.KrbtgtLinkBacklinks | Should -HaveCount 1
                $user.ResultantPasswordPolicyDN | Should -Be 'CN=PSO,DC=example,DC=com'
            }
            finally { $connection.Dispose() }
        }
        Should -Invoke Invoke-MtLdapSearch -ModuleName Maester -ParameterFilter {
            $Attributes -contains 'msDS-ResultantPSO' -and $Attributes -contains 'msDS-SecondaryKrbTgtNumber' -and
            @($Attributes | Where-Object { $_ -in 'unicodePwd', 'supplementalCredentials', 'ntPwdHistory', 'msDS-ManagedPassword' }).Count -eq 0
        }
    }

    It 'reports foreign DC metadata as unknown without erasing the forest inventory' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            @(
                [pscustomobject]@{ DistinguishedName = 'CN=NTDS Settings,CN=DC1,CN=Servers,CN=East\,Branch,CN=Sites,CN=Configuration,DC=example,DC=com'; objectClass = @('nTDSDSA'); options = 1; 'msDS-Behavior-Version' = 10 }
                [pscustomobject]@{ DistinguishedName = 'CN=NTDS Settings,CN=DC2,CN=Servers,CN=East\,Branch,CN=Sites,CN=Configuration,DC=example,DC=com'; objectClass = @('nTDSDSA'); options = $null }
            )
        } -ParameterFilter { $Filter -eq '(objectClass=nTDSDSA)' }
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{ name = 'East,Branch' }
        } -ParameterFilter { $Filter -eq '(objectClass=site)' }
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            if ($SearchBase -match '^CN=DC1,') { [pscustomobject]@{ name = 'DC1'; dNSHostName = 'dc1.example.com'; serverReference = 'CN=DC1,OU=DCs,DC=example,DC=com' } }
            else { [pscustomobject]@{ name = 'DC2'; dNSHostName = 'dc2.child.example.com'; serverReference = 'CN=DC2,OU=DCs,DC=child,DC=example,DC=com' } }
        } -ParameterFilter { $Filter -eq '(objectClass=server)' }
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            if ($SearchBase -match 'DC=child,') { throw 'Foreign naming context unavailable' }
            [pscustomobject]@{ operatingSystem = 'Windows Server 2025'; operatingSystemVersion = '10.0 (26100)'; 'msDS-IsRODC' = $false }
        } -ParameterFilter { $Filter -eq '(objectClass=computer)' }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $dcs = @(Get-MtLdapDomainController -Connection $connection -ConfigurationNamingContext 'CN=Configuration,DC=example,DC=com')
                $dcs | Should -HaveCount 2
                $dcs[0].Site | Should -Be 'East,Branch'
                $dcs[0].OperatingSystemVersion | Should -Be '10.0 (26100)'
                $dcs[0].LdapPort | Should -BeNullOrEmpty
                $dcs[0].SslPort | Should -BeNullOrEmpty
                $dcs[1].CollectionError | Should -Match 'cross-domain visibility'
                $dcs[1].OperatingSystem | Should -BeNullOrEmpty
                $dcs[1].IsReadOnly | Should -BeFalse
                $dcs[1].IsGlobalCatalog | Should -BeFalse
            }
            finally { $connection.Dispose() }
        }
    }

    It 'reads RID availability from the RID manager and exposes stable domain role DNs' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{ DistinguishedName = 'DC=example,DC=com'; name = 'example'; 'msDS-Behavior-Version' = 10; pwdProperties = 17; maxPwdAge = [timespan]::Zero; lockoutDuration = [timespan]::Zero; fSMORoleOwner = 'CN=NTDS Settings,CN=DC1,CN=Servers,CN=Site,CN=Sites,CN=Configuration,DC=example,DC=com' }
        } -ParameterFilter { $Filter -eq '(objectClass=domainDNS)' }
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{ rIDAvailablePool = 4611686014132422709L; fSMORoleOwner = 'CN=NTDS Settings,CN=DC1,CN=Servers,CN=Site,CN=Sites,CN=Configuration,DC=example,DC=com' }
        } -ParameterFilter { $Filter -eq '(objectClass=rIDManager)' }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $domain = Get-MtLdapDomain -Connection $connection -SearchBase 'DC=example,DC=com'
                $domain.DomainMode | Should -Be 'Windows2025Domain'
                $domain.DomainLevelValue | Should -Be 10
                $domain.RIDAvailablePool | Should -Be 4611686014132422709L
                $domain.PdcOwnerDistinguishedName | Should -Match '^CN=NTDS Settings,'
                $domain.ComplexityEnabled | Should -BeTrue
                $domain.ReversibleEncryptionEnabled | Should -BeTrue
                $domain.PasswordExpirationDisabled | Should -BeTrue
                $domain.LockoutRequiresAdminUnlock | Should -BeTrue
            }
            finally { $connection.Dispose() }
        }
    }
}
