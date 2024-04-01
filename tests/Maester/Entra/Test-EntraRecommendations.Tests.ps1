BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
    $EntraRecommendations = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'directory/recommendations' -OutputType Hashtable
    Write-Verbose "Found $($EntraRecommendations.Count) Entra recommendations"
}

Describe "Entra Recommendations" -Tag "Entra", "Security", "All" -ForEach $EntraRecommendations {
    It "Entra Recommendation: <displayName>" {
        #region Add detailed test description
        $ActionSteps = $actionSteps | Sort-Object -Property 'stepNumber' | Select-Object -ExpandProperty text -EA SilentlyContinue
        $ActionSteps = $ActionSteps -join "`n`n"
        $ResultMarkdown = $insights + "`n`nRemediation actions:`n`n" + $ActionSteps
        Add-MtTestResultDetail -Description $benefits -Result $ResultMarkdown
        #endregion
        # Actual test
        $status | Should -Be "completedBySystem" -Because $benefits
    }
}