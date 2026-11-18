function Get-MtConditionalAccessPolicyPlan {
    <#
    .SYNOPSIS
    Returns Conditional Access policy plans with their complete rule inventories.

    .DESCRIPTION
    Reads the beta plans and rules endpoints through Maester's Graph session cache. Rules are kept in their
    original Graph shape, including controls and rule-specific conditions. Shared conditions and owners stay
    on the parent plan. Empty plan inventories return no objects; failed reads terminate instead of hiding plans.
    This preview API accepts Policy.Read.All; write permissions are not required.
    For delegated access, Microsoft documents Conditional Access Administrator as the least privileged supported
    built-in role for listing plans; an appropriate custom role is also supported.
    On 18 November 2026, julien-ly reported successful plan and rule reads in one tenant with either Global Reader
    or Security Reader and delegated Policy.Read.All. This describes observed preview behavior in that tenant;
    validate plan and rule access with the intended audit identity against Microsoft's documented requirements.
    Existing CA checks read plans through the combined inventory, so callers who can read standalone policies
    may still encounter a plan-read error.

    .PARAMETER MetadataOnly
    Reads only plan metadata and does not request child rules. Useful for accountability checks.

    .PARAMETER DisableCache
    Forwards an explicit diagnostic caller's cache choice to every inventory request. Security checks leave the
    switch unset so that they use the same tenant snapshot as the rest of the Maester run.

    .EXAMPLE
    Get-MtConditionalAccessPolicyPlan

    Returns each plan and its rules without modifying the cached Graph objects.

    .LINK
    https://maester.dev/docs/commands/Get-MtConditionalAccessPolicyPlan

    .LINK
    https://learn.microsoft.com/graph/api/conditionalaccessroot-list-plans?view=graph-rest-beta

    .LINK
    https://github.com/maester365/maester/pull/2733#issuecomment-6979345045
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [switch] $MetadataOnly,
        [switch] $DisableCache
    )

    Write-Verbose -Message 'Reading Conditional Access policy plan metadata and rule inventories.'
    $plans = @(Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/plans' -ApiVersion beta -DisableCache:$DisableCache -ErrorAction Stop)
    $inventory = [System.Collections.Generic.List[object]]::new()
    foreach ($plan in $plans) {
        if ([string]::IsNullOrWhiteSpace([string]$plan.id)) { throw 'Conditional Access plan inventory contains a plan without an ID.' }
        $planId = [uri]::EscapeDataString([string]$plan.id)
        $copy = $plan | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
        if (-not $MetadataOnly) {
            $copy['rules'] = @(Invoke-MtGraphRequest -RelativeUri "identity/conditionalAccess/plans/$planId/rules" -ApiVersion beta -DisableCache:$DisableCache -ErrorAction Stop)
        }
        $inventory.Add([pscustomobject]$copy)
    }
    return $inventory.ToArray()
}
