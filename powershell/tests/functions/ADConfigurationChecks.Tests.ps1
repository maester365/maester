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
        $script:detail | Should -Match 'Advisory status \| ✅ Meets advisory'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'reports 60 days as the effective lifetime only when the attribute is unset' {
        $script:state.Configuration.TombstoneLifetime = $null
        Test-MtAdTombstoneLifetime | Should -BeTrue
        $script:detail | Should -Match 'Configured tombstoneLifetime \| Not set'
        $script:detail | Should -Match 'Effective tombstone lifetime \| 60 days'
        $script:detail | Should -Match 'default \(60 days\) \| True'
        $script:detail | Should -Match 'Advisory status \| ⚠️ Below advisory'
        Test-MtAdTombstoneLifetime -RecommendedMinimumDays 30 | Should -BeTrue
        $script:detail | Should -Match 'Advisory status \| ✅ Meets advisory'
    }

    It 'errors rather than assuming a default if the Directory Service object is missing' {
        $script:state.Configuration.DirectoryServiceRetrieved = $false
        $script:state.Configuration.TombstoneLifetime = $null
        { Test-MtAdTombstoneLifetime } | Should -Throw '*Directory Service object*'
        { Test-MtAdDsHeuristicsCount } | Should -Throw '*Directory Service object*'
        { Test-MtAdSpnMappings } | Should -Throw '*Directory Service object*'
    }

    It 'errors on invalid tombstone values rather than treating them as advisory-only findings' -ForEach @(
        @{ Value = 0 }
        @{ Value = -1 }
        @{ Value = 'invalid' }
    ) {
        $script:state.Configuration.TombstoneLifetime = $Value
        { Test-MtAdTombstoneLifetime } | Should -Throw
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
        Test-MtAdKdsRootKeysCount -KeyInventoryReadAccessConfirmed $true | Should -BeFalse
        $script:detail | Should -Match 'No KDS root keys'
    }

    It 'investigates the documented two-key case with a single boolean return' {
        $script:state.Configuration.KdsRootKeys += [PSCustomObject]@{ 'msKds-CreateTime' = [datetime]'2025-01-01' }
        Test-MtAdKdsRootKeysCount -KeyInventoryReadAccessConfirmed $true | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $Investigate }
        $script:detail | Should -Not -Match 'Recommended Count'
    }

    It 'does not silently omit a KDS key with unavailable creation metadata' {
        $script:state.Configuration.KdsRootKeys += [PSCustomObject]@{ Name = 'Unreadable metadata' }
        { Test-MtAdKdsRootKeysCount } | Should -Throw '*inventory is incomplete*'
    }

    It 'investigates zero visible keys unless complete read access was confirmed' {
        $script:state.Configuration.KdsRootKeys = @()
        Test-MtAdKdsRootKeysCount | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $Investigate }
        $script:detail | Should -Match 'not proof that keys are missing'
        $script:detail | Should -Not -Match 'create a third'
    }

    It 'does not recommend another key from an unconfirmed two-key inventory' {
        $script:state.Configuration.KdsRootKeys += [PSCustomObject]@{ 'msKds-CreateTime' = [datetime]'2025-01-01' }
        Test-MtAdKdsRootKeysCount | Should -BeTrue
        $script:detail | Should -Match 'complete inventory is not confirmed'
        $script:detail | Should -Not -Match 'create a third'
    }
}
