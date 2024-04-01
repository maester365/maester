BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
    $EntraRecommendations = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'directory/recommendations' -OutputType Hashtable
}

Describe "Entra Recommendations" {
    Context "<displayName>" -Tag "Entra", "Security", "All" -ForEach @( $EntraRecommendations ){
        $_.insights | Should -BeNullOrEmpty
    }
}