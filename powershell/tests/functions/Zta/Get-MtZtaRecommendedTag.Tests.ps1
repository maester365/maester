# Unit tests for Get-MtZtaRecommendedTag.
# Verifies CategoryMappings traversal, pillar-tag union, deterministic ordering, and
# the >10%-Other coverage warning.

Describe 'Get-MtZtaRecommendedTag — tag derivation' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'

        $script:settings = [pscustomobject]@{
            FocusMechanisms = @('Tag','Conditional','DataDriven','Severity')
            PillarTagMap    = [pscustomobject]@{
                Identity = @('Identity','MFA')
                Devices  = @('Intune')
                Network  = @('GSA')
                Data     = @('Purview')
            }
            CategoryMappings = @(
                [pscustomobject]@{ Category='IdentityPosture'; MatchPillar='Identity'; MatchCategoryAny=@(); MaesterTagBoost=@('Identity-Boost') }
                [pscustomobject]@{ Category='DevicePosture';   MatchPillar='Devices';  MatchCategoryAny=@(); MaesterTagBoost=@('Device-Boost') }
                [pscustomobject]@{ Category='NetworkPosture';  MatchPillar='Network';  MatchCategoryAny=@(); MaesterTagBoost=@('Net-Boost') }
                [pscustomobject]@{ Category='DataPosture';     MatchPillar='Data';     MatchCategoryAny=@(); MaesterTagBoost=@('Data-Boost') }
            )
        }
    }

    BeforeEach {
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        $script:bundle = Join-Path ([System.IO.Path]::GetTempPath()) ("mt-zta-tag-$([guid]::NewGuid())")
        New-Item -ItemType Directory -Force -Path $script:bundle | Out-Null
        Copy-Item (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')
        Copy-Item (Join-Path $script:fixtureDir 'manifest.sample.json') (Join-Path $script:bundle 'manifest.json')
    }

    AfterEach {
        if ($script:bundle -and (Test-Path $script:bundle)) { Remove-Item -Recurse -Force $script:bundle }
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
    }

    It 'returns empty array when MtZtaContext is unset' {
        $tags = @(Get-MtZtaRecommendedTag)
        $tags.Count | Should -Be 0
    }

    It 'returns empty array when ZTA loaded but no failed tests' {
        # Override fixture to a no-failure version.
        $clean = Get-Content (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json') -Raw | ConvertFrom-Json
        foreach ($t in $clean.Tests) { $t.TestStatus = 'Passed' }
        $clean | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')

        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $script:settings
        $tags = @(Get-MtZtaRecommendedTag)
        $tags.Count | Should -Be 0
    }

    It 'emits pillar literals plus PillarTagMap aliases for each failed pillar' {
        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $script:settings
        $tags = @(Get-MtZtaRecommendedTag)
        # Fixture has Failed tests in Identity, Devices, Network (Data only has a Skipped).
        $tags | Should -Contain 'Identity'
        $tags | Should -Contain 'Devices'
        $tags | Should -Contain 'Network'
        $tags | Should -Not -Contain 'Data'
        $tags | Should -Contain 'MFA'      # PillarTagMap[Identity]
        $tags | Should -Contain 'Intune'   # PillarTagMap[Devices]
        $tags | Should -Contain 'GSA'      # PillarTagMap[Network]
    }

    It 'emits MaesterTagBoost from CategoryMappings hits' {
        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $script:settings
        $tags = @(Get-MtZtaRecommendedTag)
        $tags | Should -Contain 'Identity-Boost'
        $tags | Should -Contain 'Device-Boost'
        $tags | Should -Contain 'Net-Boost'
    }

    It 'returns deterministic (sorted) output' {
        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $script:settings
        $first  = @(Get-MtZtaRecommendedTag)
        $second = @(Get-MtZtaRecommendedTag)
        ($first -join ',') | Should -Be ($second -join ',')
        ($first -join ',') | Should -Be (($first | Sort-Object) -join ',')
    }

    It 'uses default PillarTagMap when no ZtaSettings provided' {
        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
        # No CategoryMappings on the context → every failed test classifies as
        # 'Other' → the cmdlet emits a >10% warning by design. Suppress it here
        # because we're explicitly testing the no-settings fallback path, not
        # the coverage-warning path (that has its own It below).
        $tags = @(Get-MtZtaRecommendedTag -WarningAction SilentlyContinue)
        # Defaults include MFA / ConditionalAccess / PIM for Identity etc.
        $tags | Should -Contain 'Identity'
        $tags | Should -Contain 'MFA'
    }

    It 'warns when more than 10% of failed tests classify as Other' {
        # Mappings that match nothing in the fixture -> all 4 failures land in Other.
        $emptyMappings = [pscustomobject]@{
            CategoryMappings = @(
                [pscustomobject]@{ Category='SomethingElse'; MatchPillar='NoSuchPillar'; MatchCategoryAny=@(); MaesterTagBoost=@('x') }
            )
        }
        Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $emptyMappings

        $warningOutput = $null
        Get-MtZtaRecommendedTag -WarningAction SilentlyContinue -WarningVariable warningOutput | Out-Null
        $warningOutput | Should -Not -BeNullOrEmpty
        ($warningOutput -join ' ') | Should -Match 'Other'
    }
}
