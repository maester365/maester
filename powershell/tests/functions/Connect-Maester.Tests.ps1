BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Keep -Service All tests isolated from optional service modules that may not be installed.
    $script:createdStubs = @()
    foreach ($cmd in 'Get-AzContext','Connect-AzAccount','Connect-ExchangeOnline','Connect-IPPSSession','Get-ConnectionInformation','Connect-MgGraph','Connect-MicrosoftTeams') {
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

Describe 'Connect-Maester' {
    It 'Offers GitHub as a -Service option' {
        $serviceParameter = (Get-Command Connect-Maester).Parameters['Service']
        $validateSet = $serviceParameter.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -First 1

        $validateSet.ValidValues | Should -Contain 'GitHub'
    }

    It 'Offers ActiveDirectory as a -Service option' {
        $serviceParameter = (Get-Command Connect-Maester).Parameters['Service']
        $validateSet = $serviceParameter.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -First 1

        $validateSet.ValidValues | Should -Contain 'ActiveDirectory'
    }

    It 'Offers GitHubOrganization as a parameter' {
        (Get-Command Connect-Maester).Parameters.Keys | Should -Contain 'GitHubOrganization'
    }

    It 'Offers ClientTimeout as a double parameter' {
        $clientTimeoutParameter = (Get-Command Connect-Maester).Parameters['ClientTimeout']

        $clientTimeoutParameter | Should -Not -BeNullOrEmpty
        $clientTimeoutParameter.ParameterType | Should -Be ([double])
    }

    It 'Passes IncludePreview to Get-MtGraphScope' {
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Get-MtGraphScope -ModuleName Maester { @('AgentIdentity.Read.All') }

        Connect-Maester -IncludePreview

        Should -Invoke Get-MtGraphScope -ModuleName Maester -Times 1 -Exactly `
            -ParameterFilter { $IncludePreview }
    }

    It 'Passes an explicit ClientTimeout to Connect-MgGraph' {
        Mock Connect-MgGraph -ModuleName Maester {}

        Connect-Maester -ClientTimeout 900

        Should -Invoke Connect-MgGraph -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $ClientTimeout -eq 900 }
    }

    It 'Does not pass ClientTimeout to Connect-MgGraph when omitted' {
        Mock Connect-MgGraph -ModuleName Maester {}

        Connect-Maester

        Should -Invoke Connect-MgGraph -ModuleName Maester -Times 1 -Exactly -ParameterFilter { -not $PSBoundParameters.ContainsKey('ClientTimeout') }
    }

    It 'Does not connect to Graph when ClientTimeout is used with a non-Graph service' {
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Connect-MtGitHub -ModuleName Maester {}

        Connect-Maester -Service GitHub -ClientTimeout 900

        Should -Invoke Connect-MgGraph -ModuleName Maester -Times 0 -Exactly
    }

    It 'Calls Connect-MtGitHub when -Service GitHub is specified' {
        Mock Connect-MtGitHub -ModuleName Maester {}

        Connect-Maester -Service GitHub

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 1 -Exactly
    }

    It 'Passes -GitHubOrganization to Connect-MtGitHub' {
        Mock Connect-MtGitHub -ModuleName Maester -ParameterFilter { $Organization -eq 'myorg' } {}

        Connect-Maester -Service GitHub -GitHubOrganization 'myorg'

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Organization -eq 'myorg' }
    }

    It 'Validates Active Directory through the protocol-aware target selector' {
        Mock Connect-MtAdTarget -ModuleName Maester {
            InModuleScope Maester {
                $__MtSession.ADConnection = [PSCustomObject]@{
                    Connected          = $true
                    ProtocolValidated  = $true
                    ResolvedServer     = 'dc01.contoso.com'
                    ResolvedDomain     = 'contoso.com'
                    ResolvedForest     = 'contoso.com'
                    AuthenticationMode = 'Negotiate'
                    TlsMode            = 'Ldaps'
                }
            }
        }

        $verboseOutput = Connect-Maester -Service ActiveDirectory -Verbose 4>&1

        Should -Invoke Connect-MtAdTarget -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $AuthMode -eq 'Negotiate' -and $TlsMode -eq 'Auto'
        }
        $verboseOutput -join "`n" | Should -Match "resolved target 'dc01.contoso.com'.*auth 'Negotiate'.*TLS 'Ldaps'"
    }

    It 'Forwards Active Directory target, credential, authentication, and TLS options' {
        $credential = [PSCredential]::new('CONTOSO\Maester', (ConvertTo-SecureString 'not-a-real-password' -AsPlainText -Force))
        Mock Connect-MtAdTarget -ModuleName Maester {
            InModuleScope Maester {
                $__MtSession.ADConnection = [PSCustomObject]@{
                    Connected          = $true
                    ProtocolValidated  = $true
                    ResolvedServer     = 'dc02.contoso.com'
                    ResolvedDomain     = 'contoso.com'
                    ResolvedForest     = 'contoso.com'
                    AuthenticationMode = 'Basic'
                    TlsMode            = 'StartTls'
                }
            }
        }

        Connect-Maester -Service ActiveDirectory -ActiveDirectoryServer 'dc02.contoso.com' -ActiveDirectoryDomain 'contoso.com' -ActiveDirectoryForest 'contoso.com' -ActiveDirectoryCredential $credential -ActiveDirectoryAuthMode Basic -ActiveDirectoryTlsMode StartTls

        Should -Invoke Connect-MtAdTarget -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $ActiveDirectoryServer -eq 'dc02.contoso.com' -and
            $ActiveDirectoryDomain -eq 'contoso.com' -and
            $ActiveDirectoryForest -eq 'contoso.com' -and
            $ActiveDirectoryCredential.UserName -eq 'CONTOSO\Maester' -and
            $AuthMode -eq 'Basic' -and
            $TlsMode -eq 'StartTls'
        }
    }

    It 'Does not call opt-in services when -Service All is specified' {
        Mock Get-AzContext -ModuleName Maester { [PSCustomObject]@{ Account = 'test@contoso.com' } }
        Mock Get-MtDataverseEnvironmentUrl -ModuleName Maester { $null }
        Mock Connect-ExchangeOnline -ModuleName Maester {}
        Mock Connect-IPPSSession -ModuleName Maester {}
        Mock Get-ConnectionInformation -ModuleName Maester { @() }
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Connect-MicrosoftTeams -ModuleName Maester {}
        Mock Connect-MtGitHub -ModuleName Maester { throw 'Connect-MtGitHub should not be called for -Service All.' }
        Mock Connect-MtAdTarget -ModuleName Maester { throw 'Connect-MtAdTarget should not be called for -Service All.' }

        Connect-Maester -Service All 3>$null 6>$null

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 0 -Exactly
        Should -Invoke Connect-MtAdTarget -ModuleName Maester -Times 0 -Exactly
    }
}
