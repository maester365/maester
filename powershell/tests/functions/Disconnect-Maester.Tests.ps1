BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Disconnect-Maester - GitHub session lifecycle' {
    BeforeEach {
        Mock Disconnect-MgGraph -ModuleName Maester {}

        InModuleScope Maester {
            $__MtSession.Connections      = @()
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.Connections      = @()
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
        }
    }

    Context 'Default name (Disconnect-Maester)' {
        It 'clears GitHub session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Disconnect-Maester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
                $__MtSession.GitHubCache.Count | Should -Be 0
            }
        }
    }

    Context 'Module-qualified invocation (Maester\Disconnect-Maester)' {
        It 'clears GitHub session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Maester\Disconnect-Maester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
                $__MtSession.GitHubCache.Count | Should -Be 0
            }
        }
    }

    Context 'Disconnect-MtMaester alias' {
        It 'clears GitHub session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Disconnect-MtMaester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
                $__MtSession.GitHubCache.Count | Should -Be 0
            }
        }
    }

    Context 'Disconnect-MtGraph alias' {
        It 'does not clear GitHub session state' {
            InModuleScope Maester {
                $__MtSession.Connections      = @('GitHub')
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Disconnect-MtGraph 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubConnection.Organization | Should -Be 'myorg'
                $__MtSession.GitHubAuthHeader | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader['Authorization'] | Should -Be 'Bearer token'
                $__MtSession.GitHubCache['foo'] | Should -Be 'bar'
            }
        }
    }

    Context 'When no GitHub state exists' {
        It 'Produces no GitHub-related host output' {
            $hostOutput = Disconnect-Maester 6>&1 | Out-String
            $hostOutput | Should -Not -Match 'Disconnected from GitHub'
        }
    }
}

Describe 'Disconnect-Maester - Active Directory session lifecycle' {
    BeforeEach {
        Mock Disconnect-MgGraph -ModuleName Maester {}

        InModuleScope Maester {
            $__MtSession.Connections = @()
            $__MtSession.ADConnection = [PSCustomObject]@{
                Connected        = $true
                DomainController = 'dc01.contoso.com'
            }
            $__MtSession.ADCredential = [PSCredential]::new('CONTOSO\Maester', ([System.Security.SecureString]::new()))
            $__MtSession.ADCache = @{ DomainState = [PSCustomObject]@{ Domain = 'contoso.com' } }
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.Connections = @()
            $__MtSession.ADConnection = $null
            $__MtSession.ADCredential = $null
            $__MtSession.ADCache = @{}
        }
    }

    It 'Clears Active Directory state even if another Connect-Maester call replaced the service list' {
        InModuleScope Maester {
            $__MtSession.Connections = @('Graph')
        }

        Disconnect-Maester 6>$null

        InModuleScope Maester {
            $__MtSession.ADConnection | Should -BeNullOrEmpty
            $__MtSession.ADCredential | Should -BeNullOrEmpty
            $__MtSession.ADCache.Count | Should -Be 0
        }
    }

    It 'Preserves Active Directory state when only Disconnect-MtGraph is requested' {
        Disconnect-MtGraph 6>$null

        InModuleScope Maester {
            $__MtSession.ADConnection.Connected | Should -BeTrue
            $__MtSession.ADCredential.UserName | Should -Be 'CONTOSO\Maester'
            $__MtSession.ADCache.Count | Should -Be 1
        }
    }
}

Describe 'Disconnect-Maester - service disconnects' {
    BeforeAll {
        # The Exchange Online and Teams modules are optional; stand in for their commands when they are not installed.
        $script:createdStubs = @()
        $stubBodies = @{
            'Disconnect-ExchangeOnline' = {
                [CmdletBinding()]
                param([switch]$Confirm)
                $null = $PSBoundParameters
            }
        }
        foreach ($cmd in 'Disconnect-ExchangeOnline', 'Disconnect-MicrosoftTeams') {
            if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
                $stubBody = if ($stubBodies.ContainsKey($cmd)) { $stubBodies[$cmd] } else { { } }
                New-Item -Path "function:global:$cmd" -Value $stubBody | Out-Null
                $script:createdStubs += $cmd
            }
        }
    }

    AfterAll {
        foreach ($cmd in $script:createdStubs) {
            Remove-Item -Path "function:global:$cmd" -ErrorAction SilentlyContinue
        }
    }

    BeforeEach {
        Mock Disconnect-MgGraph -ModuleName Maester {}
        Mock Disconnect-ExchangeOnline -ModuleName Maester {}
        Mock Disconnect-MicrosoftTeams -ModuleName Maester {}

        InModuleScope Maester {
            $__MtSession.Connections = @('Graph', 'ExchangeOnline', 'Teams')
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.Connections = @()
        }
    }

    It 'Disconnects from Exchange Online without asking for confirmation' {
        # Pester hands -Confirm to a mock as extra arguments ('-Confirm:', False) instead of binding it.
        $script:exchangeArguments = $null
        Mock Disconnect-ExchangeOnline -ModuleName Maester { $script:exchangeArguments = @($args) }

        Disconnect-Maester 6>$null

        Should -Invoke Disconnect-ExchangeOnline -ModuleName Maester -Times 1 -Exactly
        ($script:exchangeArguments -join ' ') | Should -Match '-Confirm:\s+False'
    }

    It 'Still disconnects the other services when <Failing> fails' -ForEach @(
        @{ Failing = 'Microsoft Graph'; Command = 'Disconnect-MgGraph' }
        @{ Failing = 'Exchange Online'; Command = 'Disconnect-ExchangeOnline' }
        @{ Failing = 'Microsoft Teams'; Command = 'Disconnect-MicrosoftTeams' }
    ) {
        Mock $Command -ModuleName Maester { throw 'disconnect failed' }

        # Called directly: a script block passed to Should would keep the warning variable in its own scope.
        Disconnect-Maester -WarningVariable disconnectWarnings -WarningAction SilentlyContinue 6>$null

        "$disconnectWarnings" | Should -BeLike "*$Command*disconnect failed*"

        foreach ($other in 'Disconnect-MgGraph', 'Disconnect-ExchangeOnline', 'Disconnect-MicrosoftTeams') {
            Should -Invoke $other -ModuleName Maester -Times 1 -Exactly
        }
    }
}
