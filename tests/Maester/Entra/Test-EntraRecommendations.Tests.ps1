BeforeDiscovery {
    try {
        $EntraRecommendations = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'directory/recommendations?$expand=impactedResources' -OutputType Hashtable
        Write-Verbose "Found $($EntraRecommendations.Count) Entra recommendations"
    } catch {
        Write-Verbose "Authentication needed. Please call Connect-MgGraph."
    }
}

Describe "Entra Recommendations" -Tag "Maester", "Entra", "Security", "All", "Recommendation" -ForEach $EntraRecommendations {
    It "MT.1024: Entra Recommendation - <displayName>. See https://maester.dev/docs/tests/MT.1024" -Tag "MT.1024", $recommendationType {

        $EntraPremiumRecommendations = @(
            "insiderRiskPolicy",
            "userRiskPolicy",
            "signinRiskPolicy"
        )
        $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
        if ( $EntraIDPlan -ne "P2" ) {
            $EntraPremiumRecommendations | ForEach-Object {
                if ( $id -match "$($_)$" ) {
                    Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
                    return $null
                }
            }
        }

        if ( $status -match "dismissed" ) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Status:Dismissed for '$($id)'"
            return $null
        }

        #region Add detailed test description
        $ActionSteps = $actionSteps | Sort-Object -Property 'stepNumber' | ForEach-Object {
            $_.text + "[$($_.actionUrl.displayName)]($($_.actionUrl.url))."
        }
        $ActionSteps = $ActionSteps -join "`n`n"
        if ($status -ne 'completedBySystem' -and $impactedResources) {
            $impactedResourcesList = "`n`n#### Impacted resources`n`n | Status | Name | First detected| `n"
            $impactedResourcesList += "| --- | --- | --- |`n"
            foreach ($resource in $impactedResources) {
                if ($resource.status -eq 'completedBySystem') {
                    $resourceResult = "✅ Pass"
                } else {
                    $resourceResult = "❌ Fail"
                }
                $impactedResourcesList += "| $($resourceResult) | [$($resource.displayName)]($($resource.portalUrl)) | $($resource.addedDateTime) | `n"
            }
        }
        $ResultMarkdown = $insights + $impactedResourcesList + "`n`n#### Remediation actions:`n`n" + $ActionSteps
        Add-MtTestResultDetail -Description $benefits -Result $ResultMarkdown
        #endregion
        # Actual test
        $status | Should -Be "completedBySystem" -Because $benefits
    }
}