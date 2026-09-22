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

AfterAll {
    foreach ($cmd in $script:createdStubs) {
        Remove-Item -Path "function:global:$cmd" -ErrorAction SilentlyContinue
    }
}

Describe 'Active Directory Protocol Contracts' {

    Describe 'Root-forest implicit credentials' {
        BeforeEach {
            InModuleScope Maester {
                $script:testLogonServer = $env:LOGONSERVER
                $env:LOGONSERVER = '\\dc02.misoule02.local'
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
                    DefaultNamingContext       = 'DC=misoule02,DC=local'
                    ConfigurationNamingContext = 'CN=Configuration,DC=misoule02,DC=local'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=misoule02,DC=local'
                    DnsHostName                = 'dc02.misoule02.local'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=misoule02,DC=local', 'CN=Configuration,DC=misoule02,DC=local', 'CN=Schema,CN=Configuration,DC=misoule02,DC=local')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'misoule02.local'
                        nCName      = 'DC=misoule02,DC=local'
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
                $__MtSession.ADConnection.ResolvedServer | Should -Be 'dc02.misoule02.local'
                $__MtSession.ADConnection.ResolvedDomain | Should -Be 'misoule02.local'
                $__MtSession.ADConnection.ResolvedForest | Should -Be 'misoule02.local'
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
                if ($Name -eq '_ldap._tcp.dc._msdcs.child.misoule02.local' -and $Type -eq 'SRV') {
                    return [PSCustomObject]@{
                        NameTarget = 'dc03.child.misoule02.local.'
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
                    DefaultNamingContext       = 'DC=child,DC=misoule02,DC=local'
                    ConfigurationNamingContext = 'CN=Configuration,DC=child,DC=misoule02,DC=local'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=child,DC=misoule02,DC=local'
                    DnsHostName                = 'dc03.child.misoule02.local'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=child,DC=misoule02,DC=local', 'CN=Configuration,DC=child,DC=misoule02,DC=local', 'CN=Schema,CN=Configuration,DC=child,DC=misoule02,DC=local')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'child.misoule02.local'
                        nCName      = 'DC=child,DC=misoule02,DC=local'
                        trustParent = 'DC=misoule02,DC=local'
                    },
                    [PSCustomObject]@{
                        dnsRoot     = 'misoule02.local'
                        nCName      = 'DC=misoule02,DC=local'
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

        It "Passing -ActiveDirectoryDomain 'child.misoule02.local' should resolve to DC03" {
            InModuleScope Maester {
                Connect-MtAdTarget -ActiveDirectoryDomain 'child.misoule02.local'
                $__MtSession.ADConnection.ResolvedServer | Should -Be 'dc03.child.misoule02.local'
                $__MtSession.ADConnection.ResolvedDomain | Should -Be 'child.misoule02.local'
                $__MtSession.ADConnection.ResolvedForest | Should -Be 'misoule02.local'
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
                if ($Name -eq '_ldap._tcp.dc._msdcs.misoule03.local' -and $Type -eq 'SRV') {
                    return [PSCustomObject]@{
                        NameTarget = 'dc04.misoule03.local.'
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
                    DefaultNamingContext       = 'DC=misoule03,DC=local'
                    ConfigurationNamingContext = 'CN=Configuration,DC=misoule03,DC=local'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=misoule03,DC=local'
                    DnsHostName                = 'dc04.misoule03.local'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=misoule03,DC=local', 'CN=Configuration,DC=misoule03,DC=local', 'CN=Schema,CN=Configuration,DC=misoule03,DC=local')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'misoule03.local'
                        nCName      = 'DC=misoule03,DC=local'
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

        It "Passing -ActiveDirectoryForest 'misoule03.local' should resolve to DC04" {
            InModuleScope Maester {
                Connect-MtAdTarget -ActiveDirectoryForest 'misoule03.local'
                $__MtSession.ADConnection.ResolvedServer | Should -Be 'dc04.misoule03.local'
                $__MtSession.ADConnection.ResolvedDomain | Should -Be 'misoule03.local'
                $__MtSession.ADConnection.ResolvedForest | Should -Be 'misoule03.local'
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
                        } | Add-Member -MemberType ScriptMethod -Name 'StartTransportLayerSecurity' -Value { param($controls) } -PassThru

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
                if ($Name -eq '_ldap._tcp.dc._msdcs.misoule02.local' -and $Type -eq 'SRV') {
                    return [PSCustomObject]@{
                        NameTarget = 'dc02.misoule02.local.'
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
                    DefaultNamingContext       = 'DC=misoule02,DC=local'
                    ConfigurationNamingContext = 'CN=Configuration,DC=misoule02,DC=local'
                    SchemaNamingContext        = 'CN=Schema,CN=Configuration,DC=misoule02,DC=local'
                    DnsHostName                = 'dc02.misoule02.local'
                    ForestFunctionality        = 7
                    DomainFunctionality        = 7
                    NamingContexts             = @('DC=misoule02,DC=local', 'CN=Configuration,DC=misoule02,DC=local', 'CN=Schema,CN=Configuration,DC=misoule02,DC=local')
                    SupportedLdapVersion       = @(3)
                    SupportedSaslMechanisms    = @('GSSAPI', 'GSS-SPNEGO')
                }
            }
            Mock Invoke-MtLdapSearch -ModuleName Maester {
                return @(
                    [PSCustomObject]@{
                        dnsRoot     = 'misoule02.local'
                        nCName      = 'DC=misoule02,DC=local'
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
                Connect-MtAdTarget -ActiveDirectoryDomain 'misoule02.local' -TlsMode Auto
                $__MtSession.ADConnection.TlsMode | Should -Be 'StartTls'
            }
            $script:connectionCalls.Count | Should -Be 2
            $script:connectionCalls[0].Port | Should -Be 636
            $script:connectionCalls[0].UseStartTls | Should -BeFalse
            $script:connectionCalls[1].Port | Should -Be 389
            $script:connectionCalls[1].UseStartTls | Should -BeTrue
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
