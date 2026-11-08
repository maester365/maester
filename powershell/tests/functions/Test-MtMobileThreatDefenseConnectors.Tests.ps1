BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtMobileThreatDefenseConnectors
}

Describe 'Test-MtMobileThreatDefenseConnectors' {
    BeforeEach {
        $script:Result = $null
        $script:Connector = [pscustomobject]@{
            id = 'c2b688fe-48c0-464b-a89c-67041aa8fcb2'
            partnerState = 'enabled'
            lastHeartbeatDateTime = '2026-11-08T10:00:00Z'
        }
        Mock -ModuleName Maester Get-Date { [datetime]'2026-11-08T12:00:00Z' }
        Mock -ModuleName Maester Invoke-MtGraphRequest { $script:Connector }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedCustomReason)
            $script:Result = $Result
        }
    }

    It 'Passes for an enabled connector with a recent heartbeat' {
        Test-MtMobileThreatDefenseConnectors | Should -BeTrue
        $script:Result | Should -BeLike '*Enabled with a recent heartbeat*'
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
            $RelativeUri -eq 'deviceManagement/mobileThreatDefenseConnectors' -and $ApiVersion -eq 'beta'
        }
    }

    It 'Explains <State> without changing it to a pass' -ForEach @(
        @{ State = 'notSetUp'; Reason = '*Setup is incomplete*device threat messages are blocked*' }
        @{ State = 'unavailable'; Reason = '*deprovisioned*' }
        @{ State = 'available'; Reason = '*Turn on a platform toggle*' }
        @{ State = 'unresponsive'; Reason = '*unresponsive*Intune ignores*' }
        @{ State = 'error'; Reason = '*reported an error*' }
        @{ State = 'unknownFutureValue'; Reason = '*Unrecognized connector state*' }
        @{ State = 'newPartnerState'; Reason = '*Unrecognized connector state*' }
    ) {
        $script:Connector.partnerState = $State

        Test-MtMobileThreatDefenseConnectors | Should -BeFalse
        $script:Result | Should -BeLike $Reason
    }

    It 'Explains a missing heartbeat for <Heartbeat>' -ForEach @(
        @{ Heartbeat = '0001-01-01T00:00:00Z' }
        @{ Heartbeat = $null }
    ) {
        $script:Connector.lastHeartbeatDateTime = $Heartbeat

        Test-MtMobileThreatDefenseConnectors | Should -BeFalse
        $script:Result | Should -BeLike '*Never received*'
        $script:Result | Should -Not -BeLike '*0001-01-01*'
    }

    It 'Reports both incomplete setup and a missing heartbeat' {
        $script:Connector.partnerState = 'notSetUp'
        $script:Connector.lastHeartbeatDateTime = '0001-01-01T00:00:00Z'

        Test-MtMobileThreatDefenseConnectors | Should -BeFalse
        $script:Result | Should -BeLike '*Setup is incomplete*'
        $script:Result | Should -BeLike '*No heartbeat has been received*'
    }

    It 'Explains a stale heartbeat' {
        $script:Connector.lastHeartbeatDateTime = '2026-11-05T12:00:00Z'

        Test-MtMobileThreatDefenseConnectors | Should -BeFalse
        $script:Result | Should -BeLike '*Heartbeat is outside the test*'
    }

    It 'Preserves the existing heartbeat boundary at <Hours> hours' -ForEach @(
        @{ Hours = 47; Expected = $true }
        @{ Hours = 48; Expected = $false }
    ) {
        $script:Connector.lastHeartbeatDateTime = ([datetime]'2026-11-08T12:00:00Z').AddHours(-$Hours)

        Test-MtMobileThreatDefenseConnectors | Should -Be $Expected
    }

    It 'Fails when one of several connectors is unhealthy and reports both' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            $script:Connector
            [pscustomobject]@{
                id = 'fc780465-2017-40d4-a0c5-307022471b92'
                partnerState = 'notSetUp'
                lastHeartbeatDateTime = '0001-01-01T00:00:00Z'
            }
        }

        Test-MtMobileThreatDefenseConnectors | Should -BeFalse
        $script:Result | Should -BeLike '*Windows Security Center*'
        $script:Result | Should -BeLike '*Microsoft Defender for Endpoint*'
    }

    It 'Escapes unknown connector IDs and states in the report table' {
        $script:Connector.id = '[link](https://example.test) | extra'
        $script:Connector.partnerState = '**unknown** | extra'

        Test-MtMobileThreatDefenseConnectors | Should -BeFalse
        $script:Result | Should -Not -BeLike '*[[]link](https://example.test)*'
        $script:Result | Should -Not -BeLike '* | extra*'
        $script:Result | Should -BeLike '*Unrecognized connector state*'
    }

    It 'Keeps the no-connectors skip' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { @() }

        Test-MtMobileThreatDefenseConnectors | Should -BeNullOrEmpty
        Should -Invoke -ModuleName Maester Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
            $SkippedBecause -eq 'Custom' -and "$SkippedCustomReason" -like '*No Mobile Threat Defense Connectors found*'
        }
    }

    It 'Propagates Graph errors' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Graph unavailable' }

        { Test-MtMobileThreatDefenseConnectors } | Should -Throw '*Graph unavailable*'
    }
}

Describe 'MT.1098 native engine results' {
    BeforeEach {
        Mock -ModuleName Maester Get-MgContext { $null }
        $script:config = [pscustomobject]@{
            Environment = [pscustomobject]@{
                Services = [pscustomobject]@{ Graph = $true }
                Licenses = @('INTUNE_A')
            }
        }
    }

    It 'Records incomplete setup as Failed with actionable result details' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{
                id = 'c2b688fe-48c0-464b-a89c-67041aa8fcb2'
                partnerState = 'notSetUp'
                lastHeartbeatDateTime = '0001-01-01T00:00:00Z'
            }
        }

        $rows = @(Invoke-MtTest -Id 'MT.1098' -Config $script:config)
        $rows | Should -HaveCount 1
        $rows[0].Result | Should -Be 'Failed'
        $rows[0].ResultDetail.TestResult | Should -BeLike '*Setup is incomplete*'
        $rows[0].ResultDetail.TestResult | Should -BeLike '*Never received*'
    }

    It 'Records the no-connectors case as Skipped through the engine' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { @() }

        $row = Invoke-MtTest -Id 'MT.1098' -Config $script:config
        $row.Result | Should -Be 'Skipped'
        $row.ReasonDetail | Should -BeLike '*No Mobile Threat Defense Connectors found*'
    }

    It 'Records unreadable connector data as Error through the engine' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Graph unavailable' }

        $row = Invoke-MtTest -Id 'MT.1098' -Config $script:config
        $row.Result | Should -Be 'Error'
        $row.ReasonDetail | Should -BeLike '*Graph unavailable*'
    }
}
