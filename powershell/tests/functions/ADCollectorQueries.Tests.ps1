BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'AD query normalization for consolidated checks' {
    BeforeEach {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection { }
    }

    It 'uses schema LDAP display names rather than common names' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{ name = 'ms-LAPS-Password'; lDAPDisplayName = 'msLAPS-Password'; objectClass = @('attributeSchema') }
        }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $objects = @(Get-MtLdapSchemaObject -Connection $connection -SchemaNamingContext 'CN=Schema,CN=Configuration,DC=example,DC=com')
                $objects[0].Name | Should -Be 'ms-LAPS-Password'
                $objects[0].LdapDisplayName | Should -Be 'msLAPS-Password'
            }
            finally { $connection.Dispose() }
        }
        Should -Invoke Invoke-MtLdapSearch -ModuleName Maester -ParameterFilter { $Attributes -contains 'lDAPDisplayName' }
    }

    It 'collects all three managed service account classes without requesting passwords' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{ name = 'Delegated'; objectClass = @('computer', 'msDS-DelegatedManagedServiceAccount'); 'msDS-DelegatedMSAState' = 2; userAccountControl = 17301504; 'msDS-AllowedToDelegateTo' = @('HTTP/managed'); 'msDS-AllowedToActOnBehalfOfOtherIdentity' = [byte[]]@(1, 2, 3) }
        }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $accounts = @(Get-MtLdapServiceAccount -Connection $connection -SearchBase 'DC=example,DC=com')
                $accounts[0].ObjectClass | Should -Contain 'msDS-DelegatedManagedServiceAccount'
                $accounts[0].DelegatedMsaState | Should -Be 2
                $accounts[0].TrustedForDelegation | Should -BeTrue
                $accounts[0].TrustedToAuthForDelegation | Should -BeTrue
                $accounts[0].AllowedToDelegateTo | Should -Contain 'HTTP/managed'
                $accounts[0].HasResourceBasedConstrainedDelegation | Should -BeTrue
            }
            finally { $connection.Dispose() }
        }
        Should -Invoke Invoke-MtLdapSearch -ModuleName Maester -ParameterFilter {
            $Filter -match 'msDS-ManagedServiceAccount' -and $Filter -match 'msDS-GroupManagedServiceAccount' -and $Filter -match 'msDS-DelegatedManagedServiceAccount' -and
            @($Attributes | Where-Object { $_ -match '^(msDS-ManagedPassword|msDS-ManagedPasswordId|msDS-ManagedPasswordPreviousId)$' }).Count -eq 0
        }
    }

    It 'reports classic KCD targets and RBCD descriptor presence separately' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{ name = 'Client'; userAccountControl = 4096; 'msDS-AllowedToDelegateTo' = @('HTTP/service.example.com'); 'msDS-AllowedToActOnBehalfOfOtherIdentity' = [byte[]]@(1, 2, 3) }
        }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $computers = @(Get-MtLdapComputer -Connection $connection -SearchBase 'DC=example,DC=com')
                $computers[0].AllowedToDelegateTo | Should -Contain 'HTTP/service.example.com'
                $computers[0].HasResourceBasedConstrainedDelegation | Should -BeTrue
                $computers[0].PSObject.Properties.Name | Should -Not -Contain 'msDS-AllowedToActOnBehalfOfOtherIdentity'
            }
            finally { $connection.Dispose() }
        }
    }

    It 'retains enabled optional feature scopes' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{ name = 'Recycle Bin Feature'; 'msDS-EnabledFeatureBL' = @('CN=Partitions,CN=Configuration,DC=example,DC=com') }
        }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $features = @(Get-MtLdapOptionalFeature -Connection $connection -ConfigurationNamingContext 'CN=Configuration,DC=example,DC=com')
                $features[0].IsEnabled | Should -BeTrue
                $features[0].EnabledScopes | Should -HaveCount 1
            }
            finally { $connection.Dispose() }
        }
    }

    It 'normalizes binary CreatorSid as a SID rather than UTF-8 text' {
        InModuleScope Maester {
            $sid = ConvertFrom-MtLdapValue -AttributeName 'mS-DS-CreatorSID' -Value ([byte[]]@(1, 1, 0, 0, 0, 0, 0, 5, 11, 0, 0, 0))
            $sid.Value | Should -Be 'S-1-5-11'
        }
    }

    It 'distinguishes a missing Directory Service object from unset attributes' {
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $config = Get-MtLdapConfigurationContainer -Connection $connection -ConfigurationNamingContext 'CN=Configuration,DC=example,DC=com'
                $config.DirectoryServiceRetrieved | Should -BeFalse
                $config.SpnMappings | Should -BeNullOrEmpty
            }
            finally { $connection.Dispose() }
        }
    }

    It 'counts DHCP authorization values rather than dhcpClass container objects' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [pscustomobject]@{ name = 'DhcpRoot'; dhcpServers = @('i192.0.2.1$rcn=dhcp1.example.com$f0$sdhcp1.example.com$', 'i192.0.2.2$rcn=dhcp2.example.com$f0$sdhcp2.example.com$', 'unrecognized entry') }
        } -ParameterFilter { $Filter -eq '(objectClass=dhcpClass)' }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $config = Get-MtLdapConfigurationContainer -Connection $connection -ConfigurationNamingContext 'CN=Configuration,DC=example,DC=com'
                $config.DhcpServers | Should -HaveCount 3
                @($config.DhcpServers | Where-Object RegistrationParsed) | Should -HaveCount 2
                $config.DhcpServers.DnsName | Should -Contain 'dhcp1.example.com'
                $config.DhcpServers.IPAddress | Should -Contain '192.0.2.2'
            }
            finally { $connection.Dispose() }
        }
    }

    It 'requests the actual AD-based activation schema class' {
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try { $null = Get-MtLdapConfigurationContainer -Connection $connection -ConfigurationNamingContext 'CN=Configuration,DC=example,DC=com' }
            finally { $connection.Dispose() }
        }
        Should -Invoke Invoke-MtLdapSearch -ModuleName Maester -ParameterFilter { $Filter -eq '(objectClass=msSPP-ActivationObject)' }
    }
}

Describe 'Windows LAPS readiness accepts the production dictionary state' {
    BeforeEach {
        Mock -ModuleName Maester Get-MtADDomainState {
            [ordered]@{
                WindowsLapsInstalled = $true
                SchemaObjects = @(
                    [pscustomobject]@{ Name = 'ms-LAPS-Password'; LdapDisplayName = 'msLAPS-Password' }
                    [pscustomobject]@{ Name = 'ms-LAPS-Password-Expiration-Time'; LdapDisplayName = 'msLAPS-PasswordExpirationTime' }
                )
            }
        }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'passes with an ordered dictionary, not only a PSCustomObject fixture' {
        InModuleScope Maester { Test-MtAdLapsInstalledStatus | Should -BeTrue }
    }
}
