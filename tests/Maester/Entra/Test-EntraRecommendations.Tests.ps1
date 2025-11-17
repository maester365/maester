BeforeDiscovery {
    try {
        $EntraRecommendations = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'directory/recommendations?$expand=impactedResources' -OutputType Hashtable
        Write-Verbose "Found $($EntraRecommendations.Count) Entra recommendations"
    } catch {
        Write-Verbose 'Authentication needed. Please call Connect-MgGraph.'
    }
}

Describe "Maester/Entra" -Tag "Maester", "Entra", "Security", "Recommendation" -ForEach $EntraRecommendations {
    It "MT.1024: Entra Recommendation - <displayName>. See https://maester.dev/docs/tests/MT.1024" -Tag "MT.1024", $recommendationType {

        $EntraPremiumRecommendations = @(
            "insiderRiskPolicy",
            "userRiskPolicy",
            "signinRiskPolicy"
        )
        $recommendationUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RecommendationDetails.ReactView/recommendationId/$id"
        $recommendationLinkMd = "`n`n➡️ Open [Recommendation - $displayName]($recommendationUrl) in the Entra admin portal."

        # The $id looks like "{tenantId}_{recommendationKey}"
        # Extract the recommendation key (the part after the underscore)
        $recommendationKey = $id -replace '^[^_]+_', ''

        $recommendationSequence = @{
            "insiderRiskPolicy" = 1
            "userRiskPolicy" = 2
            "signinRiskPolicy" = 3
            "selfServicePasswordReset" = 4
            "roleOverlap" = 5
            "oneAdmin" = 6
            "passwordHashSync" = 7
            "pwagePolicyNew" = 8
            "mfaRegistrationV2" = 9
            "integratedApps" = 10
            "blockLegacyAuthentication" = 11
            "adminMFAV2" = 12
            "servicePrincipalKeyExpiry" = 13
            "applicationCredentialExpiry" = 14
            "staleAppCreds" = 15
            "staleApps" = 16
            "aadGraphDeprecationServicePrincipal" = 17
            "unusedEnterpriseApps" = 18
        }

        # Get sequential number for current recommendation, default to the key if not found
        $sequentialNumber = $recommendationKey
        if ($recommendationSequence.ContainsKey($recommendationKey)) {
            $sequentialNumber = $recommendationSequence[$recommendationKey]
        }

        $recommendationName = $recommendationKey -replace "_", " "
        $recommendationName = $recommendationName -replace "Policy", "policy"

        $testTitle = "MT.1024.$($sequentialNumber): Entra Recommendation - $displayName"

        $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
        if ( $EntraIDPlan -ne "P2" ) {
            $EntraPremiumRecommendations | ForEach-Object {
                if ( $id -match "$($_)$" ) {
                    Add-MtTestResultDetail -TestTitle $testTitle -SkippedBecause NotLicensedEntraIDP2
                    return $null
                }
            }
        }

        if ( $status -match "dismissed" ) {
            Add-MtTestResultDetail -TestTitle $testTitle -Description $benefits -SkippedBecause Custom -SkippedCustomReason "This recommendation has been **Dismissed** by an administrator.`n`nIf this test is valid for your tenant you can change its state from **Dismissed** to **Active**. $recommendationLinkMd"
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

        if( $status -eq 'completedBySystem' ) {
            $deepLink = $recommendationLinkMd
        } else {
            $deepLink = "`n`nIf the recommendation is not applicable for your tenant, it can be marked as **Dismissed** for Maester to skip it in the future. $recommendationLinkMd"
        }

        $ResultMarkdown = $insights + $deepLink + $impactedResourcesList + "`n`n#### Remediation actions:`n`n" + $ActionSteps
        Add-MtTestResultDetail -TestTitle $testTitle -Description $benefits -Result $ResultMarkdown
        #endregion
        # Actual test
        $status | Should -Be "completedBySystem" -Because $benefits
    }
}
