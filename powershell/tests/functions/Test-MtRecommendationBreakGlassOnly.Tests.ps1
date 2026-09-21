BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Test-MtRecommendationBreakGlassOnly' {
    BeforeAll {
        # subjectId maps to the affected object (a user object id for the risk recommendations).
        $script:breakGlassA = '11111111-1111-1111-1111-111111111111'
        $script:breakGlassB = '22222222-2222-2222-2222-222222222222'
        $script:regularUser = '33333333-3333-3333-3333-333333333333'
    }

    It 'Returns $false when no break-glass object IDs are supplied' {
        $impacted = @(
            [pscustomobject]@{ subjectId = $regularUser; id = 'r1'; status = 'active'; displayName = 'Regular User' }
        )
        InModuleScope Maester -Parameters @{ Impacted = $impacted } {
            param($Impacted)
            Test-MtRecommendationBreakGlassOnly -ImpactedResources $Impacted -BreakGlassObjectId @()
        } | Should -BeFalse
    }

    It 'Returns $true when the only open impacted resource is a break-glass account (matched by subjectId)' {
        $impacted = @(
            [pscustomobject]@{ subjectId = $breakGlassA; id = 'r1'; status = 'active'; displayName = 'Break Glass 1' }
        )
        InModuleScope Maester -Parameters @{ Impacted = $impacted; Bg = @($breakGlassA, $breakGlassB) } {
            param($Impacted, $Bg)
            Test-MtRecommendationBreakGlassOnly -ImpactedResources $Impacted -BreakGlassObjectId $Bg
        } | Should -BeTrue
    }

    It 'Returns $true when every open impacted resource is a break-glass account (multiple)' {
        $impacted = @(
            [pscustomobject]@{ subjectId = $breakGlassA; id = 'r1'; status = 'active'; displayName = 'Break Glass 1' }
            [pscustomobject]@{ subjectId = $breakGlassB; id = 'r2'; status = 'active'; displayName = 'Break Glass 2' }
        )
        InModuleScope Maester -Parameters @{ Impacted = $impacted; Bg = @($breakGlassA, $breakGlassB) } {
            param($Impacted, $Bg)
            Test-MtRecommendationBreakGlassOnly -ImpactedResources $Impacted -BreakGlassObjectId $Bg
        } | Should -BeTrue
    }

    It 'Returns $false when a non break-glass account still requires action' {
        $impacted = @(
            [pscustomobject]@{ subjectId = $breakGlassA; id = 'r1'; status = 'active'; displayName = 'Break Glass 1' }
            [pscustomobject]@{ subjectId = $regularUser; id = 'r2'; status = 'active'; displayName = 'Regular User' }
        )
        InModuleScope Maester -Parameters @{ Impacted = $impacted; Bg = @($breakGlassA, $breakGlassB) } {
            param($Impacted, $Bg)
            Test-MtRecommendationBreakGlassOnly -ImpactedResources $Impacted -BreakGlassObjectId $Bg
        } | Should -BeFalse
    }

    It 'Ignores resources already resolved by the system (completedBySystem)' {
        # The regular user is completed, so only the break-glass account is still open.
        $impacted = @(
            [pscustomobject]@{ subjectId = $regularUser; id = 'r1'; status = 'completedBySystem'; displayName = 'Regular User' }
            [pscustomobject]@{ subjectId = $breakGlassA; id = 'r2'; status = 'active'; displayName = 'Break Glass 1' }
        )
        InModuleScope Maester -Parameters @{ Impacted = $impacted; Bg = @($breakGlassA) } {
            param($Impacted, $Bg)
            Test-MtRecommendationBreakGlassOnly -ImpactedResources $Impacted -BreakGlassObjectId $Bg
        } | Should -BeTrue
    }

    It 'Returns $false when there are no open impacted resources' {
        $impacted = @(
            [pscustomobject]@{ subjectId = $regularUser; id = 'r1'; status = 'completedBySystem'; displayName = 'Regular User' }
        )
        InModuleScope Maester -Parameters @{ Impacted = $impacted; Bg = @($breakGlassA) } {
            param($Impacted, $Bg)
            Test-MtRecommendationBreakGlassOnly -ImpactedResources $Impacted -BreakGlassObjectId $Bg
        } | Should -BeFalse
    }

    It 'Matches a break-glass account by id when subjectId does not match' {
        $impacted = @(
            [pscustomobject]@{ subjectId = 'unmapped'; id = $breakGlassA; status = 'active'; displayName = 'Break Glass 1' }
        )
        InModuleScope Maester -Parameters @{ Impacted = $impacted; Bg = @($breakGlassA) } {
            param($Impacted, $Bg)
            Test-MtRecommendationBreakGlassOnly -ImpactedResources $Impacted -BreakGlassObjectId $Bg
        } | Should -BeTrue
    }

    It 'Returns $false when the impacted resources collection is $null' {
        InModuleScope Maester -Parameters @{ Bg = @($breakGlassA) } {
            param($Bg)
            Test-MtRecommendationBreakGlassOnly -ImpactedResources $null -BreakGlassObjectId $Bg
        } | Should -BeFalse
    }
}
