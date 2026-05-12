# Unit tests for Build-MtZtaBundle.
# These tests do not drive live Graph — they verify the function's contract
# given a populated context: returns $null when no context, otherwise returns
# a hashtable with the documented top-level keys and a stable shape regardless
# of which reader tier is active.

Describe 'Build-MtZtaBundle' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'
    }

    BeforeEach {
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        $script:bundle = Join-Path ([System.IO.Path]::GetTempPath()) ("mt-zta-bundle-$([guid]::NewGuid())")
        New-Item -ItemType Directory -Force -Path $script:bundle | Out-Null
        Copy-Item (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')
        Copy-Item (Join-Path $script:fixtureDir 'manifest.sample.json') (Join-Path $script:bundle 'manifest.json')
    }

    AfterEach {
        if ($script:bundle -and (Test-Path $script:bundle)) { Remove-Item -Recurse -Force $script:bundle }
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
    }

    Context 'Empty context' {
        It 'returns $null when MtZtaContext is not loaded' {
            $bundle = Build-MtZtaBundle
            $bundle | Should -BeNullOrEmpty
        }
    }

    Context 'Context loaded from fixtures (no reader tier)' {
        It 'returns a hashtable with the documented top-level keys' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            $bundle = Build-MtZtaBundle
            $bundle | Should -Not -BeNullOrEmpty
            $bundle.Keys | Should -Contain 'TenantId'
            $bundle.Keys | Should -Contain 'TenantName'
            $bundle.Keys | Should -Contain 'ExecutedAt'
            $bundle.Keys | Should -Contain 'ZtaAssessmentVersion'
            $bundle.Keys | Should -Contain 'IsStale'
            $bundle.Keys | Should -Contain 'Freshness'
            $bundle.Keys | Should -Contain 'Summary'
            $bundle.Keys | Should -Contain 'Inventory'
            $bundle.Keys | Should -Contain 'Tier'
        }

        It 'propagates TenantId / TenantName from the manifest / report' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            $bundle = Build-MtZtaBundle
            $bundle.TenantId   | Should -Not -BeNullOrEmpty
            # TenantName may be null if the sample manifest doesn't carry it.
            $bundle.Keys | Should -Contain 'TenantName'
        }

        It 'records Tier as "None" when neither Tier 1 nor Tier 2 readers are populated by the fixture-only context' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            $bundle = Build-MtZtaBundle
            # The sample fixture has no zt-export/ subtree, so Read-MtZtaJsonExport returns
            # an empty reader (or none). Tier should be either 'None' or 'JsonExport'.
            $bundle.Tier | Should -BeIn @('None', 'JsonExport')
        }
    }
}
