Describe 'Write-Telemetry' {
    BeforeAll {
        . "$PSScriptRoot/../../internal/session/Write-Telemetry.ps1"
        . "$PSScriptRoot/../../internal/session/Get-MtInstallationId.ps1"
        function Get-MtModuleVersion { '3.1.0' }
        $script:disabled = $env:MAESTER_DISABLE_TELEMETRY
    }

    BeforeEach {
        $env:MAESTER_DISABLE_TELEMETRY = $null
        $env:MAESTER_TELEMETRY_URL = $null
        Mock Get-MgContext {
            [PSCustomObject]@{ TenantId = '00000000-0000-0000-0000-000000000000' }
        }
        Mock Get-MtInstallationId { '11111111-2222-3333-4444-555555555555' }
        $script:sent = $null
        Mock Invoke-RestMethod { $script:sent = [pscustomobject]@{ Uri = $Uri; Body = $Body | ConvertFrom-Json } }
    }

    AfterAll {
        $env:MAESTER_DISABLE_TELEMETRY = $script:disabled
        $env:MAESTER_TELEMETRY_URL = $null
    }

    It 'uses a bounded timeout for the telemetry request' {
        Write-Telemetry -EventName InvokeMaester

        Should -Invoke Invoke-RestMethod -Exactly 1 -ParameterFilter {
            $TimeoutSec -eq 3 -and $ErrorAction -eq 'Stop'
        }
    }

    It 'does not fail when the telemetry request throws' {
        Mock Invoke-RestMethod { throw 'Network failure' }

        { Write-Telemetry -EventName InvokeMaester } | Should -Not -Throw
    }

    It 'sends a run with a hash of the tenant, never the tenant ID' {
        $results = [pscustomobject]@{ Tests = @(
                [pscustomobject]@{ Id = 'MT.1001'; Result = 'Passed' }
                [pscustomobject]@{ Id = 'MT.1002'; Result = 'NotRun' }
            )
        }
        Write-Telemetry -EventName InvokeMaester -MaesterResults $results

        $script:sent.Uri | Should -Be 'https://packs.maester.cloud/api/v1/telemetry'
        $script:sent.Body.Type | Should -Be 'run'
        $script:sent.Body.Tests | Should -Be 1
        $script:sent.Body.Tenant | Should -Match '^[0-9a-f]{64}$'
        ($script:sent.Body | ConvertTo-Json -Compress) | Should -Not -Match '00000000-0000-0000-0000-000000000000'
    }

    It 'names public and built-in packs that ran, and never a private pack' {
        $package = { param($id) [pscustomobject]@{ Id = $id } }
        $results = [pscustomobject]@{ Tests = @(
                [pscustomobject]@{ Id = 'ZTA.1'; Result = 'Passed'; Package = (& $package 'maester.zero-trust-assessment') }
                [pscustomobject]@{ Id = 'ZTA.2'; Result = 'Failed'; Package = (& $package 'maester.zero-trust-assessment') }
                [pscustomobject]@{ Id = 'MP.CNT.1'; Result = 'Passed'; Package = (& $package 'contoso.public') }
                [pscustomobject]@{ Id = 'MP.SEC.1'; Result = 'Passed'; Package = (& $package 'contoso.private') }
            )
        }
        $packSet = @(
            [pscustomobject]@{ Id = 'maester.zero-trust-assessment'; Version = '1.0.0'; BuiltIn = $true; Root = '/m/packs/zero-trust-assessment'; Entry = $null }
            [pscustomobject]@{ Id = 'contoso.public'; Version = '0.2.0'; BuiltIn = $false; Root = '/s'; Entry = [pscustomobject]@{ Source = 'github.com/contoso/maester-sample'; Public = $true } }
            [pscustomobject]@{ Id = 'contoso.private'; Version = '1.0.0'; BuiltIn = $false; Root = '/s'; Entry = [pscustomobject]@{ Source = 'github.com/contoso/secret'; Public = $false } }
        )
        Write-Telemetry -EventName InvokeMaester -MaesterResults $results -PackSet $packSet

        $packs = @($script:sent.Body.Packs)
        $packs.Source | Should -Be @('maester365/maester/packs/zero-trust-assessment', 'github.com/contoso/maester-sample')
        ($packs | Where-Object Source -Like '*zero-trust*').Tests | Should -Be 2
        ($script:sent.Body | ConvertTo-Json -Compress -Depth 4) | Should -Not -Match 'secret'
    }

    It 'sends an install event only for a public pack' {
        $entry = [pscustomobject]@{ Id = 'contoso.public'; Source = 'github.com/contoso/maester-sample'; Commit = ('a' * 40); Public = $true }
        Write-Telemetry -EventName PackInstall -Pack $entry
        $script:sent.Uri | Should -Be 'https://packs.maester.cloud/api/v1/events'
        $script:sent.Body.Source | Should -Be 'github.com/contoso/maester-sample'

        $script:sent = $null
        $entry.Public = $false
        Write-Telemetry -EventName PackInstall -Pack $entry
        $script:sent | Should -BeNullOrEmpty
    }

    It 'sends nothing when MAESTER_DISABLE_TELEMETRY is set' {
        $env:MAESTER_DISABLE_TELEMETRY = '1'
        Write-Telemetry -EventName InvokeMaester
        Should -Invoke Invoke-RestMethod -Exactly 0
    }
}

Describe 'Get-MtInstallationId' {
    BeforeAll {
        . "$PSScriptRoot/../../internal/session/Get-MtInstallationId.ps1"
        function Get-MtPackHome { }
    }

    It 'creates a random ID once and then reuses it' {
        $userHome = Join-Path $TestDrive 'home'
        Mock Get-MtPackHome { [pscustomobject]@{ UserConfig = (Join-Path $TestDrive 'home/maester-config.json') } }
        $first = Get-MtInstallationId
        $first | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        Get-MtInstallationId | Should -Be $first
        (Get-Content (Join-Path $userHome 'installation-id') -Raw) | Should -Be $first
    }
}
