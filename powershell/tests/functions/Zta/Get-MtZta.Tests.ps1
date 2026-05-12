# Unit tests for Get-MtZta -Section Summary derivation + ZtaSettings passthrough.
# Section Tests / Manifest / Database are covered by Import-MtZtaResult.Tests.ps1.

Describe 'Get-MtZta -Section Summary' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'
    }

    BeforeEach {
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        $script:bundle = Join-Path ([System.IO.Path]::GetTempPath()) ("mt-zta-summary-$([guid]::NewGuid())")
        New-Item -ItemType Directory -Force -Path $script:bundle | Out-Null
        Copy-Item (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')
        Copy-Item (Join-Path $script:fixtureDir 'manifest.sample.json') (Join-Path $script:bundle 'manifest.json')
    }

    AfterEach {
        if ($script:bundle -and (Test-Path $script:bundle)) { Remove-Item -Recurse -Force $script:bundle }
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
    }

    It 'Summary returns per-pillar counts' {
        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
        $s = Get-MtZta -Section Summary

        $s.TenantId         | Should -Be '00000000-0000-0000-0000-000000000000'
        $s.TotalTests       | Should -Be 5

        # Fixture: Identity 1P/1F, Devices 0P/1F, Network 0P/1F, Data 0P/0F/1Skipped
        $s.IdentityPassed | Should -Be 1
        $s.IdentityFailed | Should -Be 1
        $s.DevicesPassed  | Should -Be 0
        $s.DevicesFailed  | Should -Be 1
        $s.NetworkFailed  | Should -Be 1
        $s.DataFailed     | Should -Be 0
        $s.DataSkipped    | Should -Be 1
    }

    It 'Summary fail ratio excludes Skipped/Planned from the denominator' {
        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
        $s = Get-MtZta -Section Summary

        # Identity: 1 Failed of (2 total - 0 skipped - 0 planned) = 0.5
        $s.IdentityFailRatio | Should -Be 0.5
        # Data: 0 Failed of (1 total - 1 skipped - 0 planned) -> denominator=0 -> max(1,0)=1 -> 0/1=0
        $s.DataFailRatio | Should -Be 0
    }

    It 'returns $null when context is unset' {
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        Get-MtZta -Section Summary | Should -BeNullOrEmpty
    }

    It 'preserves ZtaSettings on the context when passed to Import-MtZtaResult' {
        $settings = [pscustomobject]@{ FreshnessDays = 7; CategoryMappings = @() }
        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings

        $ctx = Get-MtZta
        $ctx.ZtaSettings              | Should -Not -BeNullOrEmpty
        $ctx.ZtaSettings.FreshnessDays | Should -Be 7
    }

    It 'Section FlaggedUsers returns buckets when CategoryMappings supplied' {
        $settings = [pscustomobject]@{
            CategoryMappings = @(
                [pscustomobject]@{ Category='IdentityPosture'; MatchPillar='Identity'; MatchCategoryAny=@(); MaesterTagBoost=@() }
                [pscustomobject]@{ Category='DevicePosture';   MatchPillar='Devices';  MatchCategoryAny=@(); MaesterTagBoost=@() }
                [pscustomobject]@{ Category='NetworkPosture';  MatchPillar='Network';  MatchCategoryAny=@(); MaesterTagBoost=@() }
            )
            DataDrivenSettings = [pscustomobject]@{ MaxUsersPerCategory = 50; GroupSimilar = $true }
        }
        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings

        $buckets = Get-MtZta -Section FlaggedUsers
        $buckets | Should -Not -BeNullOrEmpty
        ($buckets | Where-Object Category -eq 'IdentityPosture').Count | Should -BeGreaterThan 0
    }
}
