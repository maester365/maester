[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Test fixtures use a fake password to verify that management errors are redacted.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Cross-platform command stubs declare native WSMan parameters for Pester mock binding.'
)]
param()

BeforeAll {
    $script:createdCommandStubs = @()
    if (-not (Get-Command New-PSSessionOption -ErrorAction SilentlyContinue).Parameters.ContainsKey('OperationTimeout')) {
        function global:New-PSSessionOption {
            param(
                [int] $OperationTimeout,
                [switch] $SkipCACheck,
                [switch] $SkipCNCheck
            )
            [void]$OperationTimeout
            [void]$SkipCACheck
            [void]$SkipCNCheck
        }
        $script:createdCommandStubs += 'New-PSSessionOption'
    }

    if (-not (Get-Command New-PSWSManSessionOption -ErrorAction SilentlyContinue)) {
        function global:New-PSWSManSessionOption {
            param(
                [int] $OperationTimeout,
                [switch] $SkipCACheck,
                [switch] $SkipCNCheck
            )
            [void]$OperationTimeout
            [void]$SkipCACheck
            [void]$SkipCNCheck
        }
        $script:createdCommandStubs += 'New-PSWSManSessionOption'
    }

    if (-not (Get-Command New-PSSession -ErrorAction SilentlyContinue).Parameters.ContainsKey('ComputerName')) {
        function global:New-PSSession {
            param(
                [string] $ComputerName,
                [string] $Authentication,
                [PSCredential] $Credential,
                $SessionOption,
                [switch] $UseSSL,
                [System.Management.Automation.ActionPreference] $ErrorAction
            )
            [void]$ComputerName
            [void]$Authentication
            [void]$Credential
            [void]$SessionOption
            [void]$UseSSL
            [void]$ErrorAction
        }
        $script:createdCommandStubs += 'New-PSSession'
    }

    function global:Invoke-Command {
        param(
            $Session,
            [scriptblock] $ScriptBlock,
            [object[]] $ArgumentList,
            [System.Management.Automation.ActionPreference] $ErrorAction
        )
        [void]$Session
        [void]$ScriptBlock
        [void]$ArgumentList
        [void]$ErrorAction
    }
    $script:createdCommandStubs += 'Invoke-Command'

    function global:Remove-PSSession {
        param(
            $Session,
            [System.Management.Automation.ActionPreference] $ErrorAction
        )
        [void]$Session
        [void]$ErrorAction
    }
    $script:createdCommandStubs += 'Remove-PSSession'

    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force

    $script:createdEnablePsWsManStub = $false
    if (-not (Get-Command Enable-PSWSMan -ErrorAction SilentlyContinue)) {
        function global:Enable-PSWSMan {
            param(
                [switch] $Force,
                [System.Management.Automation.ActionPreference] $ErrorAction
            )
            [void]$Force
            [void]$ErrorAction
            $env:MT_TEST_PSWSMAN_ENABLED = 'true'
        }
        $script:createdEnablePsWsManStub = $true
    }
}

AfterAll {
    if ($script:createdEnablePsWsManStub) {
        Remove-Item function:global:Enable-PSWSMan -ErrorAction SilentlyContinue
    }

    foreach ($commandName in $script:createdCommandStubs) {
        Remove-Item "function:global:$commandName" -ErrorAction SilentlyContinue
    }
    Remove-Item env:MT_TEST_PSWSMAN_ENABLED -ErrorAction SilentlyContinue
}

Describe 'Invoke-MtADManagementCommand' {
    BeforeEach {
        InModuleScope Maester {
            $securePassword = ConvertTo-SecureString 'FixturePassword-DoNotLog' -AsPlainText -Force
            $__MtSession.ADCredential = [PSCredential]::new('CONTOSO\MaesterFixture', $securePassword)
            $__MtSession.ADConnection = [PSCustomObject]@{
                Connected      = $true
                ResolvedServer = 'dc01.contoso.com'
            }
        }

        Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
            [PSCustomObject]@{ PlatformProfile = 'WindowsPS7' }
        }
        Mock New-PSSessionOption -ModuleName Maester {
            [PSCustomObject]@{ OperationTimeout = $OperationTimeout }
        }
        Mock New-PSWSManSessionOption -ModuleName Maester {
            [PSCustomObject]@{ OperationTimeout = $OperationTimeout }
        }
        Mock New-PSSession -ModuleName Maester {
            [PSCustomObject]@{ Id = 1; State = 'Opened' }
        }
        Mock Remove-PSSession -ModuleName Maester { }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.ADCredential = $null
            $__MtSession.ADConnection = $null
        }
    }

    It 'uses a validated HTTPS Windows session and returns typed SMB configuration' {
        Mock Invoke-Command -ModuleName Maester {
            [PSCustomObject]@{
                DCName                   = 'dc01.contoso.com'
                EnableSMB1Protocol       = $false
                EnableSMB2Protocol       = $true
                EnableSMB3_1_1Protocol   = $true
                EnableSecuritySignature  = $true
                RequireSecuritySignature = $false
            }
        }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation SmbConfiguration -TimeoutSeconds 30
        }

        $result.DCName | Should -Be 'dc01.contoso.com'
        $result.EnableSMB1Protocol | Should -BeOfType ([bool])
        $result.EnableSMB2Protocol | Should -BeTrue
        $result.EnableSMB3_1_1Protocol | Should -BeTrue
        $result.EnableSecuritySignature | Should -BeTrue
        $result.RequireSecuritySignature | Should -BeFalse
        Should -Invoke New-PSSessionOption -ModuleName Maester -Times 1 -ParameterFilter {
            $OperationTimeout -eq 30000 -and -not $SkipCACheck -and -not $SkipCNCheck
        }
        Should -Invoke New-PSSession -ModuleName Maester -Times 1 -ParameterFilter {
            $ComputerName -eq 'dc01.contoso.com' -and
            $Authentication -eq 'Negotiate' -and
            $UseSSL -and
            $Credential.UserName -eq 'CONTOSO\MaesterFixture'
        }
        Should -Invoke Remove-PSSession -ModuleName Maester -Times 1
    }

    It 'targets the specified computer for an SMB configuration operation' {
        Mock Invoke-Command -ModuleName Maester {
            [PSCustomObject]@{
                DCName                   = 'dc02.contoso.com'
                EnableSMB1Protocol       = $false
                EnableSMB2Protocol       = $true
                EnableSMB3_1_1Protocol   = $true
                EnableSecuritySignature  = $true
                RequireSecuritySignature = $true
            }
        }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation SmbConfiguration -ComputerName 'dc02.contoso.com'
        }

        $result.DCName | Should -Be 'dc02.contoso.com'
        Should -Invoke New-PSSession -ModuleName Maester -Times 1 -ParameterFilter {
            $ComputerName -eq 'dc02.contoso.com'
        }
        Should -Invoke Invoke-Command -ModuleName Maester -Times 1 -ParameterFilter {
            $ArgumentList.Count -eq 1 -and $ArgumentList[0] -eq 'dc02.contoso.com'
        }
    }

    It 'uses PSWSMan for a non-Windows WSMan session' {
        Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
            [PSCustomObject]@{ PlatformProfile = 'LinuxPS7' }
        }
        Mock Get-Module -ModuleName Maester {
            [PSCustomObject]@{ Name = 'PSWSMan'; Version = [version]'3.0.0' }
        } -ParameterFilter { $ListAvailable -and $Name -eq 'PSWSMan' }
        Mock Import-Module -ModuleName Maester { }
        $env:MT_TEST_PSWSMAN_ENABLED = 'false'
        Mock Invoke-Command -ModuleName Maester {
            [PSCustomObject]@{
                Zones     = @([PSCustomObject]@{ Name = 'contoso.com' })
                Records   = @([PSCustomObject]@{ TextRepresentation = 'www 3600 IN A 192.0.2.1' })
                RootHints = @([PSCustomObject]@{ Name = '.' })
            }
        }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation DnsInventory
        }

        $result.Zones.Count | Should -Be 1
        $result.Records.Count | Should -Be 1
        $result.RootHints.Count | Should -Be 1
        Should -Invoke Import-Module -ModuleName Maester -Times 1 -ParameterFilter { $Name -eq 'PSWSMan' }
        $env:MT_TEST_PSWSMAN_ENABLED | Should -Be 'true'
        Should -Invoke New-PSWSManSessionOption -ModuleName Maester -Times 1 -ParameterFilter { $OperationTimeout -eq 60000 }
        Should -Invoke New-PSSession -ModuleName Maester -Times 1 -ParameterFilter { $UseSSL }
        Should -Invoke Remove-PSSession -ModuleName Maester -Times 1
    }

    It 'returns a capability error when PSWSMan is unavailable on Unix' {
        Mock Test-MtAdProtocolPrerequisites -ModuleName Maester {
            [PSCustomObject]@{ PlatformProfile = 'LinuxPS7' }
        }
        Mock Get-Module -ModuleName Maester { $null } -ParameterFilter { $ListAvailable -and $Name -eq 'PSWSMan' }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation DnsInventory
        }

        $result.Operation | Should -Be 'DnsInventory'
        $result.Target | Should -Be 'dc01.contoso.com'
        $result.ErrorCategory | Should -Be 'Capability'
        $result.RedactedMessage | Should -Match '^PSWSMan is required'
        Should -Invoke New-PSSession -ModuleName Maester -Times 0
    }

    It 'returns a timeout error without exposing the underlying exception' {
        Mock New-PSSession -ModuleName Maester {
            throw [System.TimeoutException]::new('FixturePassword-DoNotLog script text { Get-Secret } timed out')
        }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation DnsInventory
        }

        $result.ErrorCategory | Should -Be 'Timeout'
        $result.RedactedMessage | Should -Be 'The management operation exceeded its configured timeout.'
        ($result | Out-String) | Should -Not -Match 'FixturePassword|Get-Secret|MaesterFixture'
    }

    It 'disposes the session when remote invocation fails' {
        Mock Invoke-Command -ModuleName Maester {
            throw 'Remote operation failed.'
        }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation SmbConfiguration
        }

        $result.ErrorCategory | Should -Be 'Connection'
        Should -Invoke Remove-PSSession -ModuleName Maester -Times 1
    }

    It 'classifies and redacts authentication failures' {
        Mock New-PSSession -ModuleName Maester {
            throw 'Authentication failed for CONTOSO\MaesterFixture using FixturePassword-DoNotLog.'
        }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation SmbConfiguration
        }

        $result.ErrorCategory | Should -Be 'Authentication'
        $result.RedactedMessage | Should -Be 'Authentication failed while establishing the management session.'
        ($result | Out-String) | Should -Not -Match 'FixturePassword|MaesterFixture'
    }

    It 'classifies and redacts certificate validation failures' {
        Mock New-PSSession -ModuleName Maester {
            throw 'The server TLS certificate CN is invalid for CONTOSO\MaesterFixture.'
        }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation DnsInventory
        }

        $result.ErrorCategory | Should -Be 'CertificateValidation'
        $result.RedactedMessage | Should -Be 'TLS certificate validation failed while establishing the management session.'
        ($result | Out-String) | Should -Not -Match 'MaesterFixture'
    }

    It 'uses explicit Negotiate fallback with message encryption after HTTPS fails' {
        $script:newSessionCall = 0
        Mock New-PSSession -ModuleName Maester {
            $script:newSessionCall++
            if ($script:newSessionCall -eq 1) {
                throw 'The validated HTTPS listener is unavailable.'
            }
            [PSCustomObject]@{ Id = 2; State = 'Opened' }
        }
        Mock Invoke-Command -ModuleName Maester {
            [PSCustomObject]@{
                DCName                   = 'dc01.contoso.com'
                EnableSMB1Protocol       = $false
                EnableSMB2Protocol       = $true
                EnableSMB3_1_1Protocol   = $true
                EnableSecuritySignature  = $true
                RequireSecuritySignature = $true
            }
        }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation SmbConfiguration -AllowNegotiateFallback
        }

        $result.RequireSecuritySignature | Should -BeTrue
        Should -Invoke New-PSSession -ModuleName Maester -Times 2
        Should -Invoke New-PSSession -ModuleName Maester -Times 1 -ParameterFilter {
            -not $UseSSL -and $Authentication -eq 'Negotiate'
        }
        Should -Invoke New-PSSessionOption -ModuleName Maester -Times 1 -ParameterFilter {
            $SkipCACheck -and $SkipCNCheck -and -not $NoEncryption
        }
        Should -Invoke Remove-PSSession -ModuleName Maester -Times 1
    }

    It 'honors cancellation before creating a session' {
        $cancellationSource = [System.Threading.CancellationTokenSource]::new()
        $cancellationSource.Cancel()

        $result = InModuleScope Maester -Parameters @{ Token = $cancellationSource.Token } {
            Invoke-MtADManagementCommand -Operation DnsInventory -CancellationToken $Token
        }

        $result.ErrorCategory | Should -Be 'Cancelled'
        Should -Invoke New-PSSession -ModuleName Maester -Times 0
        $cancellationSource.Dispose()
    }

    It 'rejects an untyped SMB response' {
        Mock Invoke-Command -ModuleName Maester {
            [PSCustomObject]@{
                DCName                   = 'dc01.contoso.com'
                EnableSMB1Protocol       = 'False'
                EnableSMB2Protocol       = $true
                EnableSMB3_1_1Protocol   = $true
                EnableSecuritySignature  = $true
                RequireSecuritySignature = $true
            }
        }

        $result = InModuleScope Maester {
            Invoke-MtADManagementCommand -Operation SmbConfiguration
        }

        $result.ErrorCategory | Should -Be 'ResponseValidation'
        $result.RedactedMessage | Should -Be 'The management endpoint returned an invalid response.'
        Should -Invoke Remove-PSSession -ModuleName Maester -Times 1
    }
}
