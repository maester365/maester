function Test-MtRecommendationBreakGlassOnly {
    <#
    .SYNOPSIS
        Determines whether the only unresolved impacted resources of an Entra recommendation are configured emergency access (break-glass) accounts.

    .DESCRIPTION
        The sign-in risk and user risk recommendations (MT.1024.signinRiskPolicy / MT.1024.userRiskPolicy)
        flag every account that is not protected by a risk-based policy. Emergency access (break-glass)
        accounts are intentionally excluded from risk-based Conditional Access policies to avoid locking
        out the accounts needed to recover the tenant, so they always surface as impacted resources that
        will never be remediated.

        This function returns $true only when there is at least one impacted resource still requiring
        action and every such resource maps to a configured break-glass account (matched by subjectId or
        id). In that case the break-glass accounts are the sole reason the recommendation is not complete
        and it must not fail the test.

        It returns $false when at least one non break-glass resource still requires action, when nothing
        is still open, or when no break-glass object IDs are supplied (nothing to exclude).

    .EXAMPLE
        Test-MtRecommendationBreakGlassOnly -ImpactedResources $recommendation.impactedResources -BreakGlassObjectId $ids

        Returns $true if the only impacted resources still requiring action are the configured break-glass accounts.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # The impactedResources collection of an Entra recommendation.
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $ImpactedResources,

        # Directory object IDs of the configured emergency access (break-glass) accounts.
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]] $BreakGlassObjectId
    )

    # Nothing configured to exclude - the recommendation must be evaluated as-is.
    if (-not $BreakGlassObjectId) { return $false }

    # Only resources the system has not already resolved still count against the recommendation.
    $openResources = @($ImpactedResources | Where-Object { $_.status -ne 'completedBySystem' })
    if ($openResources.Count -eq 0) { return $false }

    # subjectId maps to the affected object (a user object id for the risk recommendations); id is
    # matched as a fallback. Both are GUIDs, so a coincidental match against a break-glass id is not
    # a practical concern.
    $nonBreakGlass = @($openResources | Where-Object {
        $_.subjectId -notin $BreakGlassObjectId -and $_.id -notin $BreakGlassObjectId
    })

    return ($nonBreakGlass.Count -eq 0)
}
