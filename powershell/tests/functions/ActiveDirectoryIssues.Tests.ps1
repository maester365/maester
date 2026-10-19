BeforeAll {
    Import-Module "$PSScriptRoot/../../../powershell/Maester.psd1" -Force
}

BeforeDiscovery {
    $script:HasDirectoryServicesProtocols = 'System.DirectoryServices.Protocols.LdapConnection' -as [type]
}

Describe 'AD-CFG-22: KDS root key count' {
    It 'Skips when zero KDS root keys are found' {
        InModuleScope Maester {
            Mock Get-MtADDomainState -ModuleName Maester {
                return [ordered]@{
                    Configuration = [PSCustomObject]@{
                        KdsRootKeys = @()
                    }
                }
            }
            Mock Add-MtTestResultDetail -ModuleName Maester { }

            $result = Test-MtAdKdsRootKeysCount
            $result | Should -Be $null
        }
    }

    It 'Passes when exactly one KDS root key exists' {
        InModuleScope Maester {
            Mock Get-MtADDomainState -ModuleName Maester {
                return [ordered]@{
                    Configuration = [PSCustomObject]@{
                        KdsRootKeys = @(
                            [PSCustomObject]@{ 'msKds-CreateTime' = [DateTime]::UtcNow }
                        )
                    }
                }
            }

            $result = Test-MtAdKdsRootKeysCount
            $result | Should -Be $true
        }
    }

    It 'Investigates when exactly two KDS root keys exist' {
        InModuleScope Maester {
            Mock Get-MtADDomainState -ModuleName Maester {
                return [ordered]@{
                    Configuration = [PSCustomObject]@{
                        KdsRootKeys = @(
                            [PSCustomObject]@{ 'msKds-CreateTime' = [DateTime]::UtcNow.AddDays(-1) }
                            [PSCustomObject]@{ 'msKds-CreateTime' = [DateTime]::UtcNow }
                        )
                    }
                }
            }

            $result = Test-MtAdKdsRootKeysCount
            $result | Should -Be $null
        }
    }

    It 'Passes when three or more KDS root keys exist' {
        InModuleScope Maester {
            Mock Get-MtADDomainState -ModuleName Maester {
                return [ordered]@{
                    Configuration = [PSCustomObject]@{
                        KdsRootKeys = @(
                            [PSCustomObject]@{ 'msKds-CreateTime' = [DateTime]::UtcNow.AddDays(-2) }
                            [PSCustomObject]@{ 'msKds-CreateTime' = [DateTime]::UtcNow.AddDays(-1) }
                            [PSCustomObject]@{ 'msKds-CreateTime' = [DateTime]::UtcNow }
                        )
                    }
                }
            }

            $result = Test-MtAdKdsRootKeysCount
            $result | Should -Be $true
        }
    }
}

Describe 'AD-DFSR-01: DFS-R subscription matching' {
    It 'Matches DC in a child OU using ServerReference' {
        InModuleScope Maester {
            Mock Get-MtADDomainState -ModuleName Maester {
                return [ordered]@{
                    DfsrSubscriptions = @(
                        [PSCustomObject]@{
                            DistinguishedName = 'CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=DC1,OU=Tier0,OU=Domain Controllers,DC=contoso,DC=com'
                            Name              = 'SYSVOL Subscription'
                            'msDFSR-Enabled'  = $true
                        }
                    )
                    DomainControllers = @(
                        [PSCustomObject]@{
                            Name            = 'DC1'
                            DnsHostName     = 'dc1.contoso.com'
                            ServerReference = 'CN=DC1,OU=Tier0,OU=Domain Controllers,DC=contoso,DC=com'
                        }
                    )
                    RootDSE = [PSCustomObject]@{ DefaultNamingContext = 'DC=contoso,DC=com' }
                }
            }

            $result = Test-MtAdDfsrSubscriptionCount
            $result | Should -Be $true
        }
    }

    It 'Reports missing subscription when ServerReference does not match' {
        InModuleScope Maester {
            Mock Get-MtADDomainState -ModuleName Maester {
                return [ordered]@{
                    DfsrSubscriptions = @(
                        [PSCustomObject]@{
                            DistinguishedName = 'CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=DC1,OU=Domain Controllers,DC=contoso,DC=com'
                            Name              = 'SYSVOL Subscription'
                            'msDFSR-Enabled'  = $true
                        }
                    )
                    DomainControllers = @(
                        [PSCustomObject]@{
                            Name            = 'DC2'
                            DnsHostName     = 'dc2.contoso.com'
                            ServerReference = 'CN=DC2,OU=Domain Controllers,DC=contoso,DC=com'
                        }
                    )
                    RootDSE = [PSCustomObject]@{ DefaultNamingContext = 'DC=contoso,DC=com' }
                }
            }

            $result = Test-MtAdDfsrSubscriptionCount
            $result | Should -Be $false
        }
    }
}

Describe 'AD-DCOMP-06: Stale enabled computers' {
    It 'Passes when there are zero stale enabled computers' {
        InModuleScope Maester {
            Mock Get-MtADDomainState -ModuleName Maester {
                return [ordered]@{
                    Computers = @(
                        [PSCustomObject]@{
                            Name           = 'PC1'
                            Enabled        = $true
                            lastLogonDate  = [DateTime]::UtcNow.AddDays(-10)
                            operatingSystem = 'Windows 11'
                        }
                    )
                }
            }

            $result = Test-MtAdComputerStaleEnabledCount
            $result | Should -Be $true
        }
    }

    It 'Returns Investigate when stale enabled computers exist' {
        InModuleScope Maester {
            Mock Get-MtADDomainState -ModuleName Maester {
                return [ordered]@{
                    Computers = @(
                        [PSCustomObject]@{
                            Name           = 'PC1'
                            Enabled        = $true
                            lastLogonDate  = [DateTime]::UtcNow.AddDays(-200)
                            operatingSystem = 'Windows 10'
                        }
                    )
                }
            }

            $result = Test-MtAdComputerStaleEnabledCount
            $result | Should -Be $null
        }
    }
}

Describe 'AD query helpers propagate errors instead of returning @()' -Skip:(-not $script:HasDirectoryServicesProtocols) {
    BeforeAll {
        InModuleScope Maester {
            $id = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier @('localhost', 389, $false, $false)
            $script:testLdapConnection = New-Object System.DirectoryServices.Protocols.LdapConnection @($id)
        }
    }

    BeforeEach {
        InModuleScope Maester {
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                throw 'Simulated LDAP query failure'
            }
        }
    }

    It 'Get-MtLdapGroup throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapGroup -Connection $script:testLdapConnection -SearchBase 'DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapGpo throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapGpo -Connection $script:testLdapConnection -SearchBase 'DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapDomainController throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapDomainController -Connection $script:testLdapConnection -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapSchemaObject throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapSchemaObject -Connection $script:testLdapConnection -SchemaNamingContext 'CN=Schema,CN=Configuration,DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapServiceAccount throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapServiceAccount -Connection $script:testLdapConnection -SearchBase 'DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapOrganizationalUnit throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapOrganizationalUnit -Connection $script:testLdapConnection -SearchBase 'DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapFineGrainedPasswordPolicy throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapFineGrainedPasswordPolicy -Connection $script:testLdapConnection -SearchBase 'DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapOptionalFeature throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapOptionalFeature -Connection $script:testLdapConnection -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapReplicationSite throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapReplicationSite -Connection $script:testLdapConnection -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapReplicationSubnet throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapReplicationSubnet -Connection $script:testLdapConnection -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapSiteContainer throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapSiteContainer -Connection $script:testLdapConnection -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }

    It 'Get-MtLdapPrinter throws on query failure' {
        InModuleScope Maester {
            { Get-MtLdapPrinter -Connection $script:testLdapConnection -SearchBase 'DC=contoso,DC=com' } |
                Should -Throw '*Simulated LDAP query failure*'
        }
    }
}

Describe 'AD-DACL tests: platform and availability checks' {
    It 'AD-DACL-02 skips with NotSupported when platform is unsupported' {
        InModuleScope Maester {
            Mock Test-MtAdDaclPlatformSupported -ModuleName Maester { $false }
            Mock Add-MtTestResultDetail -ModuleName Maester { }

            $result = Test-MtAdDaclOuObjectCount
            $result | Should -Be $null
            Assert-MockCalled Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'NotSupported' } -Exactly 1
        }
    }

    It 'AD-DACL-02 skips with Custom when DACL data is unavailable on supported platform' {
        InModuleScope Maester {
            Mock Test-MtAdDaclPlatformSupported -ModuleName Maester { $true }
            Mock Get-MtADDomainState -ModuleName Maester {
                return [ordered]@{ DaclEntries = $null }
            }
            Mock Add-MtTestResultDetail -ModuleName Maester { }

            $result = Test-MtAdDaclOuObjectCount
            $result | Should -Be $null
            Assert-MockCalled Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -eq 'DACL data is unavailable.' } -Exactly 1
        }
    }
}
