function Get-MtEntraRecommendationInstance {
    <#
    .SYNOPSIS
    Returns one MT.1024 instance per Entra recommendation of the tenant.

    .DESCRIPTION
    Instance source of the MT.1024 family. The suffix is the recommendation ID without its tenant prefix
    (MT.1024.<recommendation>), the title is the recommendation's display name and the severity its
    priority in title case, as the Maester 2.x rows showed them.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $response = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'directory/recommendations?$expand=impactedResources' -OutputType Hashtable
    $textInfo = (Get-Culture).TextInfo
    foreach ($recommendation in @($response.value)) {
        if ($null -eq $recommendation) { continue }
        [pscustomobject]@{
            Id       = $recommendation.id -replace '^[^_]+_', ''
            Title    = "$($recommendation.displayName)."
            Severity = $textInfo.ToTitleCase([string]$recommendation.priority)
            Tag      = @($recommendation.recommendationType | Where-Object { $_ })
            Data     = $recommendation
        }
    }
}

function Test-MtEntraRecommendation {
    <#
    .SYNOPSIS
    Checks that an Entra recommendation has been completed.

    .DESCRIPTION
    Runs once per Entra recommendation (directory/recommendations). Passes when Entra reports the
    recommendation as completedBySystem, or when the only impacted resources left are the configured
    emergency access (break-glass) accounts for the sign-in risk and user risk recommendations. Dismissed
    recommendations are skipped, as are Entra ID P2 recommendations in tenants without Entra ID P2.

    .LINK
    https://maester.dev/docs/tests/MT.1024
    #>
    [MaesterTest(
        Id = 'MT.1024',
        Title = 'Entra recommendations should be completed.',
        Severity = 'Medium',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('Entra', 'Maester', 'Recommendation'),
        Service = 'Graph',
        InstanceSource = 'Get-MtEntraRecommendationInstance',
        Author = 'f-bader',
        Contributor = ('merill', 'thomas-s-schmidt', 'weyCC81', 'SamErde', 'svrooij', 'earbona23')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The recommendation to check, supplied by the engine.
        $Instance
    )

    $recommendation = $Instance.Data
    $RecommendationId = $recommendation.id

    $EntraPremiumRecommendations = @(
        'insiderRiskPolicy',
        'userRiskPolicy',
        'signinRiskPolicy'
    )

    #region Build test result markdown
    $recommendationUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RecommendationDetails.ReactView/recommendationId/$($RecommendationId)"
    $recommendationLinkMd = "`n`n➡️ Open [Recommendation - $($recommendation.displayName)]($recommendationUrl) in the Entra admin portal.`n`n*Note: If the recommendation is not applicable for your tenant, it can be marked as **Dismissed** for Maester to skip it in the future.*"
    $impactedResourcesList = ''
    if ($recommendation.status -ne 'completedBySystem' -and $recommendation.impactedResources) {
        $impactedResourcesList = "`n`n#### Impacted resources`n`n| Status | Name | First detected |`n"
        $impactedResourcesList += "| --- | --- | --- |`n"
        foreach ($resource in $recommendation.impactedResources) {
            if ($resource.status -eq 'completedBySystem') {
                $resourceResult = '✅ Pass'
            } else {
                $resourceResult = '❌ Fail'
            }
            $impactedResourcesList += "| $($resourceResult) | [$($resource.displayName)]($($resource.portalUrl)) | $($resource.addedDateTime) |`n"
        }
    }
    $resultMd = $recommendation.insights + $impactedResourcesList + $recommendationLinkMd
    #endregion Build test result markdown

    #region Build test description markdown
    $actionSteps = $recommendation.actionSteps | Sort-Object -Property 'stepNumber' | ForEach-Object {
        $actionLink = ''
        if ($_.actionUrl.url) {
            $actionLink = " [$($_.actionUrl.displayName)]($($_.actionUrl.url.replace('\l','#')))."
        }
        ($_.text.replace('<br>', "`n").replace('<br/>', "`n").split("`n").trim() -replace "<a.+?href=[`"']([^`"']+)[`"'].+?>([^<]+)<\/a>", '[$2]($1)') + $actionLink
    }
    $actionSteps = $actionSteps -join "`n`n"
    $descriptionMd = "$($recommendation.benefits)`n`n#### Remediation action:`n`n${actionSteps}`n`n**Impact:** $($recommendation.remediationImpact)`n`n#### Related links:`n`n* [$($recommendation.displayName) - Microsoft Entra admin center]($recommendationUrl)"
    #endregion Build test description markdown

    $priority = $Instance.Severity

    $EntraIDPlan = Get-MtLicenseInformation -Product 'EntraID'
    if ($EntraIDPlan -ne 'P2') {
        foreach ($premiumRecommendation in $EntraPremiumRecommendations) {
            if ($RecommendationId -match "$($premiumRecommendation)$") {
                Add-MtTestResultDetail -Description $descriptionMd -Severity $priority -SkippedBecause NotLicensedEntraIDP2
                return $null
            }
        }
    }

    if ($recommendation.status -match 'dismissed') {
        Add-MtTestResultDetail -Description $descriptionMd -Severity $priority -SkippedBecause Custom -SkippedCustomReason "This recommendation has been **Dismissed** by an administrator.`n`nIf this test is valid for your tenant you can change its state from **Dismissed** to **Active**. $recommendationLinkMd"
        return $null
    }

    # Break-glass (emergency access) accounts are intentionally excluded from risk-based Conditional
    # Access policies to avoid locking out the accounts needed to recover the tenant, so the sign-in
    # risk and user risk recommendations always flag them as impacted resources that are never
    # remediated. When the configured break-glass accounts are the only accounts still flagged, they
    # are the sole reason the recommendation is not complete and must not fail the test. See #2103.
    $breakGlassAwareRecommendationTypes = @('userRiskPolicy', 'signinRiskPolicy')
    if ($recommendation.status -ne 'completedBySystem' -and $recommendation.recommendationType -in $breakGlassAwareRecommendationTypes) {
        try {
            # Pipe instead of using member access so that no configured accounts yields an empty list, not @($null).
            $breakGlassObjectId = @(Get-MtEmergencyAccessAccount | ForEach-Object { $_.ObjectId } | Where-Object { $_ })
        } catch {
            # A break-glass account that cannot be resolved must not become a false pass. Leave the
            # list empty so the exclusion does not apply and the recommendation is evaluated as-is.
            $breakGlassObjectId = @()
            Write-Verbose "MT.1024: could not resolve emergency access accounts, evaluating recommendation without break-glass exclusion. $($_.Exception.Message)"
        }

        $onlyBreakGlassImpacted = Test-MtRecommendationBreakGlassOnly -ImpactedResources $recommendation.impactedResources -BreakGlassObjectId $breakGlassObjectId
        if ($onlyBreakGlassImpacted) {
            $breakGlassNames = @($recommendation.impactedResources | Where-Object { $_.status -ne 'completedBySystem' } | ForEach-Object { $_.displayName }) -join ', '
            $breakGlassNote = "`n`n> ℹ️ The only impacted resources are configured emergency access (break-glass) accounts, which are intentionally excluded from risk-based policies and are reported here for information only: $breakGlassNames."
            Add-MtTestResultDetail -Description $descriptionMd -Severity $priority -Result ($resultMd + $breakGlassNote)
            return $true
        }
    }

    Add-MtTestResultDetail -Description $descriptionMd -Severity $priority -Result $resultMd

    return ($recommendation.status -eq 'completedBySystem')
}
