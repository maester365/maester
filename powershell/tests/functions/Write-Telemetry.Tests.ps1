Describe 'Write-Telemetry' {
    BeforeAll {
        . "$PSScriptRoot/../../internal/session/Write-Telemetry.ps1"
        . "$PSScriptRoot/../../internal/session/Get-MtInstallationId.ps1"
        . "$PSScriptRoot/../../internal/session/Send-MtTelemetryRequest.ps1"
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
        Mock Send-MtTelemetryRequest { $script:sent = [pscustomobject]@{ Uri = $Uri; Body = $Body | ConvertFrom-Json } }
        $script:run = [pscustomobject]@{ RunId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'; StartedAt = [datetime]::UtcNow.AddSeconds(-90); Stage = 'Tests' }
    }

    AfterAll {
        $env:MAESTER_DISABLE_TELEMETRY = $script:disabled
        $env:MAESTER_TELEMETRY_URL = $null
    }

    It 'hands the event to the background sender as JSON' {
        Write-Telemetry -EventName InvokeMaester -Run $script:run

        Should -Invoke Send-MtTelemetryRequest -Exactly 1 -ParameterFilter {
            $Uri -eq 'https://api.maester.dev/v1/telemetry' -and ($Body | ConvertFrom-Json).RunId -eq 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        }
    }

    It 'does not fail when the telemetry request throws' {
        Mock Send-MtTelemetryRequest { throw 'Network failure' }

        { Write-Telemetry -EventName InvokeMaester } | Should -Not -Throw
    }

    It 'sends a run with a hash of the tenant, never the tenant ID' {
        $results = [pscustomobject]@{ Tests = @(
                [pscustomobject]@{ Id = 'MT.1001'; Result = 'Passed' }
                [pscustomobject]@{ Id = 'MT.1002'; Result = 'NotRun' }
            )
        }
        Write-Telemetry -EventName InvokeMaester -MaesterResults $results

        $script:sent.Uri | Should -Be 'https://api.maester.dev/v1/telemetry'
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
        $packs.Source | Sort-Object | Should -Be @('github.com/contoso/maester-sample', 'maester365/maester/packs/zero-trust-assessment')
        ($packs | Where-Object Source -Like '*zero-trust*').Tests | Should -Be 2
        ($script:sent.Body | ConvertTo-Json -Compress -Depth 4) | Should -Not -Match 'secret'
    }

    It 'sends a start event with the run ID, and the PostHog event until PostHog is retired' {
        Write-Telemetry -EventName InvokeMaesterStart -Run $script:run

        Should -Invoke Send-MtTelemetryRequest -Exactly 1 -ParameterFilter { $Uri -eq 'https://api.maester.dev/v1/telemetry' -and ($Body | ConvertFrom-Json).Type -eq 'start' -and ($Body | ConvertFrom-Json).RunId -eq 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' }
        Should -Invoke Send-MtTelemetryRequest -Exactly 1 -ParameterFilter { $Uri -eq 'https://us.i.posthog.com/capture/' }
    }

    It 'sends when the run started, how long it took and the result counts' {
        $results = [pscustomobject]@{ Tests = @(
                [pscustomobject]@{ Id = 'MT.1001'; Result = 'Passed' }
                [pscustomobject]@{ Id = 'MT.1002'; Result = 'Failed' }
                [pscustomobject]@{ Id = 'MT.1003'; Result = 'Skipped' }
            )
        }
        Write-Telemetry -EventName InvokeMaester -Run $script:run -MaesterResults $results

        $script:sent.Body.RunId | Should -Be 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $script:sent.Body.Outcome | Should -Be 'Completed'
        $script:sent.Body.Stage | Should -BeNullOrEmpty
        $script:sent.Body.DurationMs | Should -BeGreaterOrEqual 90000
        $script:sent.Body.Results.Passed | Should -Be 1
        $script:sent.Body.Results.Failed | Should -Be 1
        $script:sent.Body.Results.Skipped | Should -Be 1
        $script:sent.Body.Tests | Should -Be 2
    }

    It 'sends an incomplete run with its stage and the error type, never the message' {
        Write-Telemetry -EventName InvokeMaester -Run $script:run -Outcome Incomplete -ErrorType 'System.Management.Automation.PipelineStoppedException'

        $script:sent.Body.Outcome | Should -Be 'Incomplete'
        $script:sent.Body.Stage | Should -Be 'Tests'
        $script:sent.Body.ErrorType | Should -Be 'System.Management.Automation.PipelineStoppedException'
    }

    It 'lists the public packs installed, and never a private one' {
        $packSet = @(
            [pscustomobject]@{ Id = 'maester.zero-trust-assessment'; Version = '1.0.0'; BuiltIn = $true; Root = '/m/packs/zero-trust-assessment'; Entry = $null }
            [pscustomobject]@{ Id = 'contoso.public'; Version = '0.2.0'; BuiltIn = $false; Root = '/s'; Entry = [pscustomobject]@{ Source = 'github.com/contoso/maester-sample'; Public = $true } }
            [pscustomobject]@{ Id = 'contoso.private'; Version = '1.0.0'; BuiltIn = $false; Root = '/s'; Entry = [pscustomobject]@{ Source = 'github.com/contoso/secret'; Public = $false } }
        )
        Write-Telemetry -EventName InvokeMaester -Run $script:run -PackSet $packSet

        @($script:sent.Body.Installed).Source | Should -Be @('github.com/contoso/maester-sample')
        @($script:sent.Body.Packs).Count | Should -Be 0
        ($script:sent.Body | ConvertTo-Json -Compress -Depth 4) | Should -Not -Match 'secret'
    }

    It 'sends an install event only for a public pack' {
        $entry = [pscustomobject]@{ Id = 'contoso.public'; Source = 'github.com/contoso/maester-sample'; Commit = ('a' * 40); Public = $true }
        Write-Telemetry -EventName PackInstall -Pack $entry
        $script:sent.Uri | Should -Be 'https://api.maester.dev/v1/events'
        $script:sent.Body.Source | Should -Be 'github.com/contoso/maester-sample'

        $script:sent = $null
        $entry.Public = $false
        Write-Telemetry -EventName PackInstall -Pack $entry
        $script:sent | Should -BeNullOrEmpty
    }

    It 'sends nothing when MAESTER_DISABLE_TELEMETRY is set' {
        $env:MAESTER_DISABLE_TELEMETRY = '1'
        Write-Telemetry -EventName InvokeMaesterStart -Run $script:run
        Write-Telemetry -EventName InvokeMaester -Run $script:run
        Should -Invoke Send-MtTelemetryRequest -Exactly 0
    }
}

Describe 'Send-MtTelemetryRequest and Wait-MtTelemetry' {
    BeforeAll {
        . "$PSScriptRoot/../../internal/session/Send-MtTelemetryRequest.ps1"
        . "$PSScriptRoot/../../internal/session/Wait-MtTelemetry.ps1"
    }

    It 'returns at once and waits at most the timeout for a request that does not answer' {
        # A listener that accepts the connection and never answers stands in for a slow service.
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        try {
            $uri = "http://127.0.0.1:$($listener.LocalEndpoint.Port)/v1/telemetry"
            $send = [System.Diagnostics.Stopwatch]::StartNew()
            Send-MtTelemetryRequest -Uri $uri -Body '{}'
            $send.Elapsed.TotalSeconds | Should -BeLessThan 1

            $wait = [System.Diagnostics.Stopwatch]::StartNew()
            { Wait-MtTelemetry -TimeoutSeconds 0.5 } | Should -Not -Throw
            $wait.Elapsed.TotalSeconds | Should -BeLessThan 2
        } finally {
            $listener.Stop()
        }
    }

    It 'does nothing when no request is pending' {
        { Wait-MtTelemetry } | Should -Not -Throw
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

    It 'uses one ID for the session when the file cannot be written' {
        Mock Get-MtPackHome { throw 'read-only home' }
        $script:MtSessionInstallationId = $null
        $first = Get-MtInstallationId
        $first | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        Get-MtInstallationId | Should -Be $first
    }
}
