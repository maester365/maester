BeforeDiscovery {
    try {
        $EntraRecommendations = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'directory/recommendations?$expand=impactedResources' -OutputType Hashtable
        Write-Verbose "Found $($EntraRecommendations.Count) Entra recommendations"
    } catch {
        Write-Verbose "Authentication needed. Please call Connect-MgGraph."
    }
}

Describe "Maester/Entra" -Tag "Maester", "Entra", "Security", "All", "Recommendation" -ForEach $EntraRecommendations {
    It "MT.1024: Entra Recommendation - <displayName>. See https://maester.dev/docs/tests/MT.1024" -Tag "MT.1024", $recommendationType {

        $EntraPremiumRecommendations = @(
            "insiderRiskPolicy",
            "userRiskPolicy",
            "signinRiskPolicy"
        )
        $recommendationUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RecommendationDetails.ReactView/recommendationId/$id"
        $recommendationLinkMd = "`n`n➡️ Open [Recommendation - $displayName]($recommendationUrl) in the Entra admin portal."

        # Hashtable to map recommendation IDs to sequential numbers
        $recommendationSequence = @{
            "0817c655-a853-4d8f-9723-3a333b5b9235_insiderRiskPolicy" = 1
            "0817c655-a853-4d8f-9723-3a333b5b9235_userRiskPolicy" = 2
            "0817c655-a853-4d8f-9723-3a333b5b9235_signinRiskPolicy" = 3
            "0817c655-a853-4d8f-9723-3a333b5b9235_selfServicePasswordReset" = 4
            "0817c655-a853-4d8f-9723-3a333b5b9235_roleOverlap" = 5
            "0817c655-a853-4d8f-9723-3a333b5b9235_oneAdmin" = 6
            "0817c655-a853-4d8f-9723-3a333b5b9235_passwordHashSync" = 7
            "0817c655-a853-4d8f-9723-3a333b5b9235_pwagePolicyNew" = 8
            "0817c655-a853-4d8f-9723-3a333b5b9235_mfaRegistrationV2" = 9
            "0817c655-a853-4d8f-9723-3a333b5b9235_integratedApps" = 10
            "0817c655-a853-4d8f-9723-3a333b5b9235_blockLegacyAuthentication" = 11
            "0817c655-a853-4d8f-9723-3a333b5b9235_adminMFAV2" = 12
            "0817c655-a853-4d8f-9723-3a333b5b9235_servicePrincipalKeyExpiry" = 13
            "0817c655-a853-4d8f-9723-3a333b5b9235_applicationCredentialExpiry" = 14
            "0817c655-a853-4d8f-9723-3a333b5b9235_staleAppCreds" = 15
            "0817c655-a853-4d8f-9723-3a333b5b9235_staleApps" = 16
        }

        # Get sequential number for current recommendation, default to the id if not found
        $sequentialNumber = $id
        if ($recommendationSequence.ContainsKey($id)) {
            $sequentialNumber = $recommendationSequence[$id]
        }

        $recommendationName = $id -replace "0817c655-a853-4d8f-9723-3a333b5b9235_", ""
        $recommendationName = $recommendationName -replace "_", " "
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
            Add-MtTestResultDetail -TestTitle $testTitle -Description $benefits -SkippedBecause Custom -SkippedCustomReason "This recommendation has been **Dismissed** by an administrator.`n`nIf this test is valid for your tenant you can change it's state from **Dismissed** to **Active**. $recommendationLinkMd"
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