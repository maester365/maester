BeforeDiscovery {
    try {
        $EntraRecommendations = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'directory/recommendations?$expand=impactedResources' -OutputType Hashtable
        Write-Verbose "Found $($EntraRecommendations.Count) Entra recommendations"
    } catch {
        Write-Verbose 'Authentication needed. Please call Connect-MgGraph.'
    }
}

Describe "Maester/Entra" -Tag "Maester", "Entra", "Security", "Recommendation" -ForEach $EntraRecommendations {
    It "MT.1024.$($_.id -replace '^[^_]+_', ''): $($_.displayName). See https://maester.dev/docs/tests/MT.1024" -Tag "MT.1024", $recommendationType {

        $EntraPremiumRecommendations = @(
            "insiderRiskPolicy",
            "userRiskPolicy",
            "signinRiskPolicy"
        )
        $recommendationUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RecommendationDetails.ReactView/recommendationId/$($_.id)"
        $recommendationLinkMd = "`n`n➡️ Open [Recommendation - $($_.displayName)]($recommendationUrl) in the Entra admin portal.`n`n*Note: If the recommendation is not applicable for your tenant, it can be marked as **Dismissed** for Maester to skip it in the future.*"
        $actionSteps = $actionSteps | Sort-Object -Property 'stepNumber' | ForEach-Object {
            if ($_.actionUrl.url) {
                $actionLink = " [$($_.actionUrl.displayName)]($($_.actionUrl.url.replace('" \l "','#')))."
            }
            $_.text.replace("<br>","`n`n") + $actionLink
        }
        $actionSteps = $ActionSteps -join "`n`n"
        $recommendationDescription = "$($_.benefits)`n`n#### Remediation action:`n`n$($_.remediationImpact)`n`n${actionSteps}"

        $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
        if ( $EntraIDPlan -ne "P2" ) {
            $EntraPremiumRecommendations | ForEach-Object {
                if ( $id -match "$($_)$" ) {
                    Add-MtTestResultDetail -Description $recommendationDescription -Severity $_.priority -SkippedBecause NotLicensedEntraIDP2
                    return $null
                }
            }
        }

        if ( $status -match "dismissed" ) {
            Add-MtTestResultDetail -Description $benefits -Severity $_.priority -SkippedBecause Custom -SkippedCustomReason "This recommendation has been **Dismissed** by an administrator.`n`nIf this test is valid for your tenant you can change its state from **Dismissed** to **Active**. $recommendationLinkMd"
            return $null
        }

        #region Add detailed test description
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

        $ResultMarkdown = $insights + $impactedResourcesList + $recommendationLinkMd
        Add-MtTestResultDetail -Description $recommendationDescription -Result $ResultMarkdown -Severity $_.priority
        #endregion
        # Actual test
        $status | Should -Be "completedBySystem" -Because $benefits
    }
}
