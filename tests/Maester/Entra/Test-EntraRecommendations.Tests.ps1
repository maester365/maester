BeforeDiscovery {
    try {
        $EntraRecommendationsResponse = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'directory/recommendations?$expand=impactedResources' -OutputType Hashtable
        $EntraRecommendations = @($EntraRecommendationsResponse.value)
        Write-Verbose "Found $($EntraRecommendations.Count) Entra recommendations"
    } catch {
        Write-Verbose 'Authentication needed. Please call Connect-MgGraph.'
    }
}

Describe "Maester/Entra" -Tag "Maester", "Entra",  "Recommendation" -ForEach $EntraRecommendations {

    # Define the test name and Id for each Entra recommendation.
    $RecommendationId = $_.id
    It "MT.1024.$($RecommendationId -replace '^[^_]+_', ''): $($_.displayName). See https://maester.dev/docs/tests/MT.1024" -Tag "MT.1024", "$($_.recommendationType)" {
        $RecommendationId = $_.id

        $EntraPremiumRecommendations = @(
            "insiderRiskPolicy",
            "userRiskPolicy",
            "signinRiskPolicy"
        )

        #region Build test result markdown
        $recommendationUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RecommendationDetails.ReactView/recommendationId/$($RecommendationId)"
        $recommendationLinkMd = "`n`n➡️ Open [Recommendation - $($_.displayName)]($recommendationUrl) in the Entra admin portal.`n`n*Note: If the recommendation is not applicable for your tenant, it can be marked as **Dismissed** for Maester to skip it in the future.*"
        $impactedResourcesList = ""
        if ($_.status -ne 'completedBySystem' -and $_.impactedResources) {
            $impactedResourcesList = "`n`n#### Impacted resources`n`n| Status | Name | First detected |`n"
            $impactedResourcesList += "| --- | --- | --- |`n"
            foreach ($resource in $_.impactedResources) {
                if ($resource.status -eq 'completedBySystem') {
                    $resourceResult = "✅ Pass"
                } else {
                    $resourceResult = "❌ Fail"
                }
                $impactedResourcesList += "| $($resourceResult) | [$($resource.displayName)]($($resource.portalUrl)) | $($resource.addedDateTime) |`n"
            }
        } #end if status -ne 'completedBySystem' and impactedResources
        $resultMd = $_.insights + $impactedResourcesList + $recommendationLinkMd
        #endregion Build test result markdown

        #region Build test description markdown
        $actionSteps = $_.actionSteps | Sort-Object -Property 'stepNumber' | ForEach-Object {
            $actionLink = ""
            if ($_.actionUrl.url) {
                $actionLink = " [$($_.actionUrl.displayName)]($($_.actionUrl.url.replace('\l','#')))."
            }
            ($_.text.replace("<br>","`n").replace("<br/>","`n").split("`n").trim() -replace "<a.+?href=[`"']([^`"']+)[`"'].+?>([^<]+)<\/a>", '[$2]($1)') + $actionLink
        }
        $actionSteps = $actionSteps -join "`n`n"
        $descriptionMd = "$($_.benefits)`n`n#### Remediation action:`n`n${actionSteps}`n`n**Impact:** $($_.remediationImpact)`n`n#### Related links:`n`n* [$($_.displayName) - Microsoft Entra admin center]($recommendationUrl)"
        #endregion Build test description markdown

        $textInfo = (Get-Culture).TextInfo
        $priority = $textInfo.ToTitleCase($_.priority)

        $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
        if ( $EntraIDPlan -ne "P2" ) {
            $EntraPremiumRecommendations | ForEach-Object {
                if ( $RecommendationId -match "$($_)$" ) {
                    Add-MtTestResultDetail -Description $descriptionMd -Severity $priority -SkippedBecause NotLicensedEntraIDP2
                    return $null
                }
            }
        }

        if ( $_.status -match "dismissed" ) {
            Add-MtTestResultDetail -Description $descriptionMd -Severity $priority -SkippedBecause Custom -SkippedCustomReason "This recommendation has been **Dismissed** by an administrator.`n`nIf this test is valid for your tenant you can change its state from **Dismissed** to **Active**. $recommendationLinkMd"
            return $null
        }

        # Break-glass (emergency access) accounts are intentionally excluded from risk-based Conditional
        # Access policies to avoid locking out the accounts needed to recover the tenant, so the sign-in
        # risk and user risk recommendations always flag them as impacted resources that are never
        # remediated. When the configured break-glass accounts are the only accounts still flagged, they
        # are the sole reason the recommendation is not complete and must not fail the test. See #2103.
        $breakGlassAwareRecommendationTypes = @('userRiskPolicy', 'signinRiskPolicy')
        if ( $_.status -ne 'completedBySystem' -and $_.recommendationType -in $breakGlassAwareRecommendationTypes ) {
            try {
                $breakGlassObjectId = @((Get-MtEmergencyAccessAccount).ObjectId)
            } catch {
                # A break-glass account that cannot be resolved must not become a false pass. Leave the
                # list empty so the exclusion does not apply and the recommendation is evaluated as-is.
                $breakGlassObjectId = @()
                Write-Verbose "MT.1024: could not resolve emergency access accounts, evaluating recommendation without break-glass exclusion. $($_.Exception.Message)"
            }

            $onlyBreakGlassImpacted = Test-MtRecommendationBreakGlassOnly -ImpactedResources $_.impactedResources -BreakGlassObjectId $breakGlassObjectId
            if ( $onlyBreakGlassImpacted ) {
                $breakGlassNames = @($_.impactedResources | Where-Object { $_.status -ne 'completedBySystem' } | ForEach-Object { $_.displayName }) -join ', '
                $breakGlassNote = "`n`n> ℹ️ The only impacted resources are configured emergency access (break-glass) accounts, which are intentionally excluded from risk-based policies and are reported here for information only: $breakGlassNames."
                Add-MtTestResultDetail -Description $descriptionMd -Severity $priority -Result ($resultMd + $breakGlassNote)
                $onlyBreakGlassImpacted | Should -BeTrue -Because "the only impacted resources are the configured emergency access (break-glass) accounts, which are intentionally excluded from risk-based policies"
                return $null
            }
        }

        Add-MtTestResultDetail -Description $descriptionMd -Severity $priority -Result $resultMd

        # Actual test
        $_.status | Should -Be "completedBySystem" -Because $_.benefits
    }
}
