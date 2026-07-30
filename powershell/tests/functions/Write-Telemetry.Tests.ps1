Describe 'Write-Telemetry' {
    BeforeAll {
        . "$PSScriptRoot/../../internal/Write-Telemetry.ps1"
    }

    BeforeEach {
        Mock Get-MgContext {
            [PSCustomObject]@{ TenantId = '00000000-0000-0000-0000-000000000000' }
        }
    }

    It 'uses a bounded timeout for the telemetry request' {
        Mock Invoke-RestMethod {}

        Write-Telemetry -EventName InvokeMaester

        Should -Invoke Invoke-RestMethod -Exactly 1 -ParameterFilter {
            $TimeoutSec -eq 5 -and $ErrorAction -eq 'Stop'
        }
    }

    It 'does not fail when the telemetry request throws' {
        Mock Invoke-RestMethod { throw 'Network failure' }

        { Write-Telemetry -EventName InvokeMaester } | Should -Not -Throw
    }
}
