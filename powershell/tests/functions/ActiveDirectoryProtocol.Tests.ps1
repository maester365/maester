[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Test fixtures use fake passwords for mock credential creation; no real secrets are involved.'
)]
param()

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    $script:createdStubs = @()
    foreach ($cmd in 'Resolve-DnsName') {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            New-Item -Path "function:global:$cmd" -Value { } | Out-Null
            $script:createdStubs += $cmd
        }
    }
}

# Target-Scoped AD Cache Keys and Group Member Cache Clearing
Describe 'Get-MtADDomainState: Target-Scoped Cache Keys' {
    It 'clears group member cache when Clear-MtADCache is invoked (global clear)' {
        InModuleScope Maester {
            $script:__MtLdapGroupMemberCache = @{'dc:group1' = @('member1')}
            Clear-MtADCache
            $script:__MtLdapGroupMemberCache.Count | Should -Be 0
        }
    }

    It 'includes target identity in metadata cache key when ResolvedDomain and ResolvedServer are set' -Skip {
        # Skipped: requires full mock environment for Get-MtADDomainState internals
    }

    It 'switching domains returns different cached data' -Skip {
        # Skipped: requires full mock environment for Get-MtADDomainState internals
    }
}

AfterAll {
    foreach ($cmd in $script:createdStubs) {
        Remove-Item -Path "function:global:$cmd" -ErrorAction SilentlyContinue
    }
}

BeforeDiscovery {
    # System.DirectoryServices.Protocols is not available on all Windows PowerShell 5.1 environments
    # (e.g. GitHub Actions windows-latest runners). Skip these tests when the assembly is missing.
    $script:HasDirectoryServicesProtocols = 'System.DirectoryServices.Protocols.LdapConnection' -as [type]
}

Describe 'Active Directory Protocol Contracts' -Skip:(-not $script:HasDirectoryServicesProtocols) {

    Describe 'Root-forest implicit credentials' {
        BeforeEach {
            InModuleScope Maester {
                $script:testLogonServer = $env:LOGONSERVER
                $env:LOGONSERVER = '\\dc01.contoso.com'
                $__MtSession.ADConnection = $null
            }

            Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
                return [PSCustomObject]@{
                    IsReady              = $true
                    AuthModes            = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
                    TlsModes             = @('Ldaps', 'StartTls')
                    PlatformProfile      = 'WindowsPS7'
                    MissingPrerequisites = @()
                }
            }
            Mock Resolve-DnsName -ModuleName Maester {
                param($Name, $Type)
                if ($Name -eq '_ldap._tcp.dc._msdcs.contoso.com' -and $Type -eq 'SRV') {
                    return [PSCustomObject]@{
                        NameTarget = 'dc01.contoso.com.'
                        Priority   = 0
                        Weight     = 100
                        DomainName = $null
                        NameHost   = $null
                    }
                }
                throw "Unexpected DNS query: $Name"
            }
            Mock New-MtLdapConnection -ModuleName Maester {
                $id = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier @('localhost', 636, $false, $false)
                return New-Object System.DirectoryServices.Protocols.LdapConnection @($id)
            }
            Mock Get-MtLdapRootDse -ModuleName Maester {
                return [PSCustomObject]@{
                    DistinguishedName          = ''
                    DefaultNamingContext       = 'DC=contoso,DC=com'
                    ConfigurationNamingContext = 'CN=Configuration,DC=contoso,DC=com'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
                    DnsHostName                = 'dc01.contoso.com'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=contoso,DC=com', 'CN=Configuration,DC=contoso,DC=com', 'CN=Schema,CN=Configuration,DC=contoso,DC=com')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'contoso.com'
                        nCName      = 'DC=contoso,DC=com'
                        trustParent = $null
                    }
                )
            }
        }

        AfterEach {
            InModuleScope Maester {
                $env:LOGONSERVER = $script:testLogonServer
                $__MtSession.ADConnection = $null
            }
        }

        It 'On Windows, ambient discovery should resolve to the joined domain controller' {
            InModuleScope Maester {
                Connect-MtAdTarget
                $__MtSession.ADConnection.ResolvedServer | Should -Be 'dc01.contoso.com'
                $__MtSession.ADConnection.ResolvedDomain | Should -Be 'contoso.com'
                $__MtSession.ADConnection.ResolvedForest | Should -Be 'contoso.com'
                $__MtSession.ADConnection.AuthenticationMode | Should -Be 'Negotiate'
                $__MtSession.ADConnection.RequestedTlsMode | Should -Be 'Auto'
                $__MtSession.ADConnection.TlsMode | Should -Be 'Ldaps'

                Get-MtADDomainState -Refresh | Out-Null
                $__MtSession.ADConnection.RequestedTlsMode | Should -Be 'Auto'
                $__MtSession.ADConnection.TlsMode | Should -Be 'Ldaps'
            }
        }
    }

    Describe 'Child-domain explicit targeting' {
        BeforeEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }

            Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
                return [PSCustomObject]@{
                    IsReady              = $true
                    AuthModes            = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
                    TlsModes             = @('Ldaps', 'StartTls')
                    PlatformProfile      = 'WindowsPS7'
                    MissingPrerequisites = @()
                }
            }
            Mock Resolve-DnsName -ModuleName Maester {
                param($Name, $Type)
                if ($Name -eq '_ldap._tcp.dc._msdcs.child.contoso.com' -and $Type -eq 'SRV') {
                    return [PSCustomObject]@{
                        NameTarget = 'dc02.child.contoso.com.'
                        Priority   = 0
                        Weight     = 100
                        DomainName = $null
                        NameHost   = $null
                    }
                }
                throw "Unexpected DNS query: $Name"
            }
            Mock New-MtLdapConnection -ModuleName Maester {
                $id = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier @('localhost', 636, $false, $false)
                return New-Object System.DirectoryServices.Protocols.LdapConnection @($id)
            }
            Mock Get-MtLdapRootDse -ModuleName Maester {
                return [PSCustomObject]@{
                    DistinguishedName          = ''
                    DefaultNamingContext       = 'DC=child,DC=contoso,DC=com'
                    ConfigurationNamingContext = 'CN=Configuration,DC=contoso,DC=com'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
                    RootDomainNamingContext    = 'DC=contoso,DC=com'
                    DnsHostName                = 'dc02.child.contoso.com'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=child,DC=contoso,DC=com', 'CN=Configuration,DC=contoso,DC=com', 'CN=Schema,CN=Configuration,DC=contoso,DC=com')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'child.contoso.com'
                        nCName      = 'DC=child,DC=contoso,DC=com'
                        trustParent = 'DC=contoso,DC=com'
                    },
                    [PSCustomObject]@{
                        dnsRoot     = 'contoso.com'
                        nCName      = 'DC=contoso,DC=com'
                        trustParent = $null
                    }
                )
            }
        }

        AfterEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }
        }

        It "Passing -ActiveDirectoryDomain 'child.contoso.com' should resolve to DC03" {
            InModuleScope Maester {
                Connect-MtAdTarget -ActiveDirectoryDomain 'child.contoso.com'
                $__MtSession.ADConnection.ResolvedServer | Should -Be 'dc02.child.contoso.com'
                $__MtSession.ADConnection.ResolvedDomain | Should -Be 'child.contoso.com'
                $__MtSession.ADConnection.ResolvedForest | Should -Be 'contoso.com'
            }
        }
    }

    Describe 'Separate-forest explicit targeting' {
        BeforeEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }

            Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
                return [PSCustomObject]@{
                    IsReady              = $true
                    AuthModes            = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
                    TlsModes             = @('Ldaps', 'StartTls')
                    PlatformProfile      = 'WindowsPS7'
                    MissingPrerequisites = @()
                }
            }
            Mock Resolve-DnsName -ModuleName Maester {
                param($Name, $Type)
                if ($Name -eq '_ldap._tcp.dc._msdcs.fabrikam.com' -and $Type -eq 'SRV') {
                    return [PSCustomObject]@{
                        NameTarget = 'dc01.fabrikam.com.'
                        Priority   = 0
                        Weight     = 100
                        DomainName = $null
                        NameHost   = $null
                    }
                }
                throw "Unexpected DNS query: $Name"
            }
            Mock New-MtLdapConnection -ModuleName Maester {
                $id = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier @('localhost', 636, $false, $false)
                return New-Object System.DirectoryServices.Protocols.LdapConnection @($id)
            }
            Mock Get-MtLdapRootDse -ModuleName Maester {
                return [PSCustomObject]@{
                    DistinguishedName          = ''
                    DefaultNamingContext       = 'DC=fabrikam,DC=com'
                    ConfigurationNamingContext = 'CN=Configuration,DC=fabrikam,DC=com'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=fabrikam,DC=com'
                    DnsHostName                = 'dc01.fabrikam.com'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=fabrikam,DC=com', 'CN=Configuration,DC=fabrikam,DC=com', 'CN=Schema,CN=Configuration,DC=fabrikam,DC=com')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'fabrikam.com'
                        nCName      = 'DC=fabrikam,DC=com'
                        trustParent = $null
                    }
                )
            }
        }

        AfterEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }
        }

        It "Passing -ActiveDirectoryForest 'fabrikam.com' should resolve to DC04" {
            InModuleScope Maester {
                Connect-MtAdTarget -ActiveDirectoryForest 'fabrikam.com'
                $__MtSession.ADConnection.ResolvedServer | Should -Be 'dc01.fabrikam.com'
                $__MtSession.ADConnection.ResolvedDomain | Should -Be 'fabrikam.com'
                $__MtSession.ADConnection.ResolvedForest | Should -Be 'fabrikam.com'
            }
        }
    }

    Describe 'Basic-over-389 rejection' {
        It 'New-MtLdapConnection with -AuthType Basic -Port 389 should throw' {
            InModuleScope Maester {
                { New-MtLdapConnection -Server 'dc01.contoso.com' -Port 389 -AuthType Basic } |
                    Should -Throw -ExpectedMessage 'Basic authentication requires LDAPS on port 636 or StartTLS.'
            }
        }
    }

    Describe 'Basic-over-LDAPS success path' {
        BeforeEach {
            $script:bindCalled = $false
            Mock New-Object -ModuleName Maester {
                param($TypeName, $ArgumentList)

                switch ($TypeName) {
                    'System.DirectoryServices.Protocols.LdapDirectoryIdentifier' {
                        return [PSCustomObject]@{ Servers = @($ArgumentList[0]); PortNumber = $ArgumentList[1] }
                    }
                    'System.DirectoryServices.Protocols.LdapConnection' {
                        $fakeSessionOptions = [PSCustomObject]@{
                            ProtocolVersion   = 3
                            ReferralChasing   = 'All'
                            SecureSocketLayer = $false
                        } | Add-Member -MemberType ScriptMethod -Name 'StartTransportLayerSecurity' -Value {
                            param($controls)
                            [void]$controls
                        } -PassThru

                        $conn = [PSCustomObject]@{
                            AuthType       = 'Negotiate'
                            Timeout        = [timespan]::FromSeconds(30)
                            SessionOptions = $fakeSessionOptions
                            Credential     = $null
                        } | Add-Member -MemberType ScriptMethod -Name 'Bind' -Value { $script:bindCalled = $true } -PassThru |
                           Add-Member -MemberType ScriptMethod -Name 'Dispose' -Value {} -PassThru
                        return $conn
                    }
                }

                & (Get-Command New-Object -CommandType Cmdlet) @PSBoundParameters
            }
        }

        It 'New-MtLdapConnection with -AuthType Basic -Port 636 should succeed' {
            InModuleScope Maester {
                $cred = [PSCredential]::new('CONTOSO\Maester', (ConvertTo-SecureString 'not-a-real-password' -AsPlainText -Force))
                $connection = New-MtLdapConnection -Server 'dc01.contoso.com' -Port 636 -AuthType Basic -Credential $cred
                $connection.SessionOptions.SecureSocketLayer | Should -BeTrue
                $connection.SessionOptions.ReferralChasing | Should -Be ([System.DirectoryServices.Protocols.ReferralChasingOptions]::None)
            }
        }

        It 'New-MtLdapConnection with -AuthType Basic should convert DNS domain format to UPN' {
            InModuleScope Maester {
                $cred = [PSCredential]::new('contoso.com\Maester', (ConvertTo-SecureString 'not-a-real-password' -AsPlainText -Force))
                $connection = New-MtLdapConnection -Server 'dc01.contoso.com' -Port 636 -AuthType Basic -Credential $cred
                # .NET Framework (PS 5.1) parses UPN into UserName + Domain; .NET Core keeps the full UPN in UserName.
                # Both are valid for Basic auth, so accept either representation.
                $validUserNameFormats = @('Maester@contoso.com', 'Maester')
                $connection.Credential.UserName | Should -BeIn $validUserNameFormats
                if ($connection.Credential.UserName -eq 'Maester') {
                    $connection.Credential.Domain | Should -Be 'contoso.com'
                }
                else {
                    $connection.Credential.Domain | Should -BeNullOrEmpty
                }
            }
        }
    }

    Describe 'StartTLS negotiation invocation' {
        BeforeEach {
            $script:startTlsCalled = $false
            Mock New-Object -ModuleName Maester {
                param($TypeName, $ArgumentList)

                switch ($TypeName) {
                    'System.DirectoryServices.Protocols.LdapDirectoryIdentifier' {
                        return [PSCustomObject]@{ Servers = @($ArgumentList[0]); PortNumber = $ArgumentList[1] }
                    }
                    'System.DirectoryServices.Protocols.LdapConnection' {
                        $fakeSessionOptions = [PSCustomObject]@{
                            ProtocolVersion   = 3
                            ReferralChasing   = 'All'
                            SecureSocketLayer = $false
                        } | Add-Member -MemberType ScriptMethod -Name 'StartTransportLayerSecurity' -Value {
                            param($controls)
                            [void]$controls
                            $script:startTlsCalled = $true
                        } -PassThru

                        $conn = [PSCustomObject]@{
                            AuthType       = 'Negotiate'
                            Timeout        = [timespan]::FromSeconds(30)
                            SessionOptions = $fakeSessionOptions
                            Credential     = $null
                        } | Add-Member -MemberType ScriptMethod -Name 'Bind' -Value {} -PassThru |
                           Add-Member -MemberType ScriptMethod -Name 'Dispose' -Value {} -PassThru
                        return $conn
                    }
                    'System.DirectoryServices.Protocols.DirectoryControlCollection' {
                        return [PSCustomObject]@{}
                    }
                }

                & (Get-Command New-Object -CommandType Cmdlet) @PSBoundParameters
            }
        }

        It 'New-MtLdapConnection with -UseStartTls -Port 389 should call StartTransportLayerSecurity' {
            InModuleScope Maester {
                { New-MtLdapConnection -Server 'dc01.contoso.com' -Port 389 -UseStartTls -AuthType Basic -Credential (
                    [PSCredential]::new('user', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
                ) } | Should -Not -Throw
            }
            $script:startTlsCalled | Should -BeTrue
        }
    }

    Describe 'TLS-resolved re-probe uses StartTLS port' {
        BeforeEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
                $script:PortsUsed = [System.Collections.Generic.List[object]]::new()
            }

            # Avoid ambient AD discovery by mocking the initial connect
            Mock Connect-MtAdTarget -ModuleName Maester {
                return [PSCustomObject]@{}
            }

            Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
                return [PSCustomObject]@{
                    IsReady              = $true
                    AuthModes            = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
                    TlsModes             = @('Ldaps', 'StartTls')
                    PlatformProfile      = 'WindowsPS7'
                    MissingPrerequisites = @()
                }
            }
            Mock New-MtLdapConnection -ModuleName Maester {
                param($Server, $Port, $AuthType, [PSCredential]$Credential, $UseStartTls)
                # Be robust to parameter naming differences in mock binding (Port vs PortNumber)
                $portValue = if ($PSBoundParameters.ContainsKey('Port')) { $Port } elseif ($PSBoundParameters.ContainsKey('PortNumber')) { $PSBoundParameters['PortNumber'] } else { $Port }
                if (-not $script:PortsUsed) {
                    $script:PortsUsed = [System.Collections.Generic.List[object]]::new()
                }
                $script:PortsUsed.Add($portValue)
                return [pscustomobject]@{ Port = $portValue }
            }
            Mock Get-MtLdapRootDse -ModuleName Maester {
                return [PSCustomObject]@{
                    DistinguishedName          = ''
                    DefaultNamingContext       = 'DC=contoso,DC=com'
                    ConfigurationNamingContext = 'CN=Configuration,DC=contoso,DC=com'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
                    DnsHostName                = 'dc01.contoso.com'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=contoso,DC=com', 'CN=Configuration,DC=contoso,DC=com', 'CN=Schema,CN=Configuration,DC=contoso,DC=com')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'contoso.com'
                        nCName      = 'DC=contoso,DC=com'
                        trustParent = $null
                    }
                )
            }
        }

        AfterEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }
        }

        It 'Re-probe with resolved TLS mode uses StartTLS port (389) on -Refresh' -Skip {
            InModuleScope Maester {
                # Initial connection with -TlsMode Auto (implicitly resolved to LDAPS or StartTLS by mocks)
                Connect-MtAdTarget

                # Replace the ADConnection object with a prepared one that has a resolved TLS mode
                $__MtSession.ADConnection = [PSCustomObject]@{
                    RequestedAuthMode = 'Negotiate'
                    TlsMode           = 'StartTls'
                }

                # Clear any previously captured ports to focus on the re-probe path
                $script:PortsUsed = [System.Collections.Generic.List[object]]::new()

                # Trigger re-probe
                Get-MtADDomainState -Refresh | Out-Null

                # Expect that the re-probe used port 389 (StartTLS), not 636 (LDAPS)
                $script:PortsUsed | Should -Contain 389
                $script:PortsUsed | Should -Not -Contain 636
            }
        }
    }

    Describe 'TLS fallback order' {
        BeforeEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }

            $script:connectionCalls = [System.Collections.Generic.List[object]]::new()

            Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
                return [PSCustomObject]@{
                    IsReady              = $true
                    AuthModes            = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
                    TlsModes             = @('Ldaps', 'StartTls')
                    PlatformProfile      = 'WindowsPS7'
                    MissingPrerequisites = @()
                }
            }
            Mock Resolve-DnsName -ModuleName Maester {
                param($Name, $Type)
                if ($Name -eq '_ldap._tcp.dc._msdcs.contoso.com' -and $Type -eq 'SRV') {
                    return [PSCustomObject]@{
                        NameTarget = 'dc01.contoso.com.'
                        Priority   = 0
                        Weight     = 100
                    }
                }
                throw "Unexpected DNS query: $Name"
            }
            Mock New-MtLdapConnection -ModuleName Maester {
                param($Server, $Port, $UseStartTls)
                $script:connectionCalls.Add([PSCustomObject]@{
                    Server      = $Server
                    Port        = $Port
                    UseStartTls = [bool]$UseStartTls
                }) | Out-Null
                if ($Port -eq 636) {
                    throw 'Connection refused on port 636'
                }
                $id = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier @('localhost', $Port, $false, $false)
                return New-Object System.DirectoryServices.Protocols.LdapConnection @($id)
            }
            Mock Get-MtLdapRootDse -ModuleName Maester {
                return [PSCustomObject]@{
                    DistinguishedName          = ''
                    DefaultNamingContext       = 'DC=contoso,DC=com'
                    ConfigurationNamingContext = 'CN=Configuration,DC=contoso,DC=com'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
                    DnsHostName                = 'dc01.contoso.com'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=contoso,DC=com', 'CN=Configuration,DC=contoso,DC=com', 'CN=Schema,CN=Configuration,DC=contoso,DC=com')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'contoso.com'
                        nCName      = 'DC=contoso,DC=com'
                        trustParent = $null
                    }
                )
            }
        }

        AfterEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }
        }

        It 'Connect-MtAdTarget should try LDAPS (636) first, then StartTLS (389)' {
            InModuleScope Maester {
                Connect-MtAdTarget -ActiveDirectoryDomain 'contoso.com' -TlsMode Auto
                $__MtSession.ADConnection.TlsMode | Should -Be 'StartTls'
            }
            $script:connectionCalls.Count | Should -Be 2
            $script:connectionCalls[0].Port | Should -Be 636
            $script:connectionCalls[0].UseStartTls | Should -BeFalse
            $script:connectionCalls[1].Port | Should -Be 389
            $script:connectionCalls[1].UseStartTls | Should -BeTrue
        }

        # Enhanced error message when both TLS modes fail
        It 'Enhanced error message when both TLS modes fail' {
            # Override the base mock so both TLS paths fail
            Mock -ModuleName Maester -CommandName New-MtLdapConnection -MockWith {
                param($Port)
                $script:connectionCalls.Add([PSCustomObject]@{ Port = $Port })
                throw [System.Exception]::new("Port $Port failed")
            }

            { InModuleScope Maester { Connect-MtAdTarget -ActiveDirectoryDomain 'contoso.com' -TlsMode Auto } } | Should -Throw '*Could not establish an LDAP connection*'
            $script:connectionCalls.Count | Should -Be 2
            $script:connectionCalls[0].Port | Should -Be 636
            $script:connectionCalls[1].Port | Should -Be 389
        }

        It 'Original exception preserved when only one TLS mode fails' {
            Mock -ModuleName Maester -CommandName New-MtLdapConnection -ParameterFilter { param($Port) $Port -eq 636 } -MockWith {
                throw [System.Exception]::new('Port 636 failed')
            }
            Mock -ModuleName Maester -CommandName New-MtLdapConnection -ParameterFilter { param($Port) $Port -eq 389 } -MockWith {
                return [PSCustomObject]@{ }
            }

            { InModuleScope Maester { Connect-MtAdTarget -ActiveDirectoryDomain 'contoso.com' -TlsMode Ldaps } } | Should -Throw
            $script:connectionCalls.Count | Should -Be 1
            $script:connectionCalls[0].Port | Should -Be 636
        }
    }

    Describe 'Selector mismatch' {
        BeforeEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }

            Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
                return [PSCustomObject]@{
                    IsReady              = $true
                    AuthModes            = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
                    TlsModes             = @('Ldaps', 'StartTls')
                    PlatformProfile      = 'WindowsPS7'
                    MissingPrerequisites = @()
                }
            }
            Mock New-MtLdapConnection -ModuleName Maester {
                $id = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier @('localhost', 636, $false, $false)
                return New-Object System.DirectoryServices.Protocols.LdapConnection @($id)
            }
            Mock Get-MtLdapRootDse -ModuleName Maester {
                return [PSCustomObject]@{
                    DistinguishedName          = ''
                    DefaultNamingContext       = 'DC=other,DC=domain,DC=com'
                    ConfigurationNamingContext = 'CN=Configuration,DC=other,DC=domain,DC=com'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=other,DC=domain,DC=com'
                    DnsHostName                = 'dc01.other.domain.com'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=other,DC=domain,DC=com', 'CN=Configuration,DC=other,DC=domain,DC=com', 'CN=Schema,CN=Configuration,DC=other,DC=domain,DC=com')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'other.domain.com'
                        nCName      = 'DC=other,DC=domain,DC=com'
                        trustParent = $null
                    }
                )
            }
        }

        AfterEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }
        }

        It 'Passing conflicting selectors should throw' {
            InModuleScope Maester {
                { Connect-MtAdTarget -ActiveDirectoryServer 'dc01.contoso.com' -ActiveDirectoryDomain 'contoso.com' } |
                    Should -Throw '*Explicit selector values must resolve to the same forest/domain/server.*'
            }
        }

        It 'Pass-through validation failures preserve the established session' {
            InModuleScope Maester {
                $__MtSession.ADConnection = [PSCustomObject]@{
                    Connected         = $true
                    ProtocolValidated = $true
                    ResolvedServer    = 'dc02.contoso.com'
                }

                { Connect-MtAdTarget -ActiveDirectoryServer 'dc01.contoso.com' -ActiveDirectoryDomain 'contoso.com' -PassThru } |
                    Should -Throw '*Explicit selector values must resolve to the same forest/domain/server.*'
                $__MtSession.ADConnection.Connected | Should -BeTrue
                $__MtSession.ADConnection.ProtocolValidated | Should -BeTrue
                $__MtSession.ADConnection.ResolvedServer | Should -Be 'dc02.contoso.com'
            }
        }
    }

    Describe 'Non-Windows implicit targeting' {
        BeforeEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }

            Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
                return [PSCustomObject]@{
                    IsReady              = $true
                    AuthModes            = @('Negotiate', 'Kerberos', 'Basic')
                    TlsModes             = @('Ldaps', 'StartTls')
                    PlatformProfile      = 'LinuxPS7'
                    MissingPrerequisites = @()
                }
            }
        }

        AfterEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }
        }

        It 'On Linux/Mac, ambient discovery without explicit credentials should fail gracefully' {
            InModuleScope Maester {
                { Connect-MtAdTarget } |
                    Should -Throw '*Non-Windows platforms require an explicit Active Directory endpoint*'
            }
        }
    }

    Describe 'IP/SPN mismatch' {
        BeforeEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }

            Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
                return [PSCustomObject]@{
                    IsReady              = $true
                    AuthModes            = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
                    TlsModes             = @('Ldaps', 'StartTls')
                    PlatformProfile      = 'WindowsPS7'
                    MissingPrerequisites = @()
                }
            }
            Mock New-MtLdapConnection -ModuleName Maester {
                param($Server)
                if ($Server -match '^\d+\.\d+\.\d+\.\d+$') {
                    throw "SPN mismatch: cannot form service principal name for IP address $Server"
                }
                $id = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier @('localhost', 636, $false, $false)
                return New-Object System.DirectoryServices.Protocols.LdapConnection @($id)
            }
        }

        AfterEach {
            InModuleScope Maester {
                $__MtSession.ADConnection = $null
            }
        }

        It 'Connecting by IP address with Negotiate auth should fail with SPN mismatch' {
            InModuleScope Maester {
                { Connect-MtAdTarget -ActiveDirectoryServer '192.168.1.1' } |
                    Should -Throw '*SPN mismatch*'
            }
        }
    }
}
