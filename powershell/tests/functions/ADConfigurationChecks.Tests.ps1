BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtAdTombstoneLifetime, Test-MtAdDsHeuristicsCount, Test-MtAdSpnMappings, Test-MtAdRecycleBinStatus, Test-MtAdOptionalFeatureCount, Test-MtAdKdsRootKeysCount
}

Describe 'AD configuration, forest and optional-feature checks' {
    BeforeEach {
        $script:detail = $null
        $script:state = [PSCustomObject]@{
            Forest = [PSCustomObject]@{ Name = 'example.test'; ForestMode = 'Windows2016Forest' }
            Configuration = [PSCustomObject]@{
                DirectoryServiceRetrieved = $true
                TombstoneLifetime = 180
                DsHeuristics = $null
                SpnMappings = @('HOST=HTTP')
                KdsRootKeys = @([PSCustomObject]@{ 'msKds-CreateTime' = [datetime]'2024-01-01' })
            }
            OptionalFeatures = @(
                [PSCustomObject]@{ Name = 'Recycle Bin Feature'; IsEnabled = $true; EnabledScopes = @('CN=Partitions,CN=Configuration,DC=example,DC=test') }
                [PSCustomObject]@{ Name = 'Other Feature'; IsEnabled = $false; EnabledScopes = @() }
            )
        }
        Mock Get-MtADDomainState -ModuleName Maester { $script:state }
        Mock Add-MtTestResultDetail -ModuleName Maester { $script:detail = $Result }
    }

    It 'reports an explicitly configured 180-day tombstone lifetime, not the default' {
        Test-MtAdTombstoneLifetime | Should -BeTrue
        $script:detail | Should -Match 'Configured tombstoneLifetime \| 180 days'
        $script:detail | Should -Match 'Effective tombstone lifetime \| 180 days'
        $script:detail | Should -Match 'default \(60 days\) \| False'
    }

    It 'reports 60 days as the effective lifetime only when the attribute is unset' {
        $script:state.Configuration.TombstoneLifetime = $null
        Test-MtAdTombstoneLifetime | Should -BeTrue
        $script:detail | Should -Match 'Configured tombstoneLifetime \| Not set'
        $script:detail | Should -Match 'Effective tombstone lifetime \| 60 days'
        $script:detail | Should -Match 'default \(60 days\) \| True'
    }

    It 'errors rather than assuming a default if the Directory Service object is missing' {
        $script:state.Configuration.DirectoryServiceRetrieved = $false
        $script:state.Configuration.TombstoneLifetime = $null
        { Test-MtAdTombstoneLifetime } | Should -Throw '*Directory Service object*'
        { Test-MtAdDsHeuristicsCount } | Should -Throw '*Directory Service object*'
        { Test-MtAdSpnMappings } | Should -Throw '*Directory Service object*'
    }

    It 'investigates unset dSHeuristics without treating it as an inventory error' {
        Test-MtAdDsHeuristicsCount | Should -BeTrue
        $script:detail | Should -Match 'not set'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $Investigate }
    }

    It 'fails when Recycle Bin exists but is not enabled' {
        $script:state.OptionalFeatures[0].IsEnabled = $false
        Test-MtAdRecycleBinStatus | Should -BeFalse
        $script:detail | Should -Match 'not enabled'
    }

    It 'combines available and enabled counts with feature scope details' {
        Test-MtAdOptionalFeatureCount | Should -BeTrue
        $script:detail | Should -Match 'Available optional features \| 2'
        $script:detail | Should -Match 'Enabled optional features \| 1'
        $script:detail | Should -Match 'Recycle Bin Feature \| True \| CN=Partitions'
        $script:detail | Should -Match 'Other Feature \| False \| None'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $Investigate }
    }

    It 'errors when an optional feature is missing enabled-scope data' {
        $script:state.OptionalFeatures[0].PSObject.Properties.Remove('EnabledScopes')
        { Test-MtAdOptionalFeatureCount } | Should -Throw '*scopes were not collected*'
    }

    It 'fails for zero KDS root keys rather than assuming gMSAs are unused' {
        $script:state.Configuration.KdsRootKeys = @()
        Test-MtAdKdsRootKeysCount | Should -BeFalse
        $script:detail | Should -Match 'No KDS root keys'
    }

    It 'investigates the documented two-key case with a single boolean return' {
        $script:state.Configuration.KdsRootKeys += [PSCustomObject]@{ 'msKds-CreateTime' = [datetime]'2025-01-01' }
        Test-MtAdKdsRootKeysCount | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $Investigate }
        $script:detail | Should -Not -Match 'Recommended Count'
    }

    It 'does not silently omit a KDS key with unavailable creation metadata' {
        $script:state.Configuration.KdsRootKeys += [PSCustomObject]@{ Name = 'Unreadable metadata' }
        { Test-MtAdKdsRootKeysCount } | Should -Throw '*inventory is incomplete*'
    }
}
