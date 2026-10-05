# Legacy Pester fixture: a stale copy of the 2024-style family wrapper for MT.1024. The ID
# is built at discovery time, so there is no static ID; 3.0 supersedes it because the
# literal start of the It name is a built-in family's parent ID and a dot ("MT.1024.").
# Fixture-only change: when Graph is not available, discovery falls back to inline data so
# the instances exist without a tenant.
BeforeDiscovery {
    try {
        $EntraRecommendationsResponse = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'directory/recommendations' -OutputType Hashtable
        $EntraRecommendations = @($EntraRecommendationsResponse.value)
    } catch {
        $EntraRecommendations = @(
            @{ id = '00000000_aadConnectDeprecated'; displayName = 'Upgrade Azure AD Connect'; status = 'active'; recommendationType = 'aadConnectDeprecated' }
            @{ id = '00000000_mfaRegistrationV2'; displayName = 'Require MFA registration'; status = 'completedBySystem'; recommendationType = 'mfaRegistrationV2' }
        )
    }
}

Describe "Maester/Entra" -Tag "Maester", "Entra", "Recommendation" -ForEach $EntraRecommendations {
    It "MT.1024.$($_.id -replace '^[^_]+_', ''): $($_.displayName). See https://maester.dev/docs/tests/MT.1024" -Tag "MT.1024", "$($_.recommendationType)" {
        $_.status | Should -BeIn @('completedBySystem', 'completedByUser', 'dismissed') -Because "the recommendation is still active"
    }
}
