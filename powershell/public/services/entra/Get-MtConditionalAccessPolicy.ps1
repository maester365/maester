function Get-MtConditionalAccessPolicy {
    <#
    .SYNOPSIS
    Returns standalone Conditional Access policies and effective policy plan rules.

    .DESCRIPTION
    Reads standalone policies and beta policy plans through the Graph session cache. Each plan rule is projected
    into the policy shape used by existing checks: inherited conditions are combined without dropping exclusions,
    and nested grant/session controls are exposed at the policy level. The rule retains its own ID and state,
    with planId, planDisplayName, planOwners, sourceType, sharedConditions and ruleConditions identifying its source.
    Owners are metadata only. Disabled and report-only rules retain their states and are not promoted to enabled.
    An empty plan inventory is valid. A failed read or an unsafe condition combination terminates the inventory
    instead of presenting partial data as complete. Reading requires CA read access, not write permissions.
    Delegated callers also need a supported Microsoft Entra role: Conditional Access Administrator is the least
    privileged built-in role supported for listing plans; an appropriate custom role is also supported.
    Policy.Read.All alone is not sufficient for every delegated caller. Existing CA checks read plans through
    the combined inventory, so callers who can read standalone policies may now encounter a plan-read error.
    See https://learn.microsoft.com/graph/api/conditionalaccessroot-list-plans?view=graph-rest-beta

    .PARAMETER StandaloneOnly
    Returns only standalone policies, without reading the preview plans endpoint. This is an explicit inventory
    selection for callers that need original Graph policy objects, not a fallback used by security checks.

    .PARAMETER DisableCache
    Forwards an explicit diagnostic caller's cache choice. Security checks leave this switch unset.

    .EXAMPLE
    Get-MtConditionalAccessPolicy | Where-Object state -EQ enabled

    Returns enabled standalone policies and enabled plan rules with effective conditions.

    .EXAMPLE
    Get-MtConditionalAccessPolicy -StandaloneOnly

    Returns the standalone policy inventory without making a plans request.

    .LINK
    https://maester.dev/docs/commands/Get-MtConditionalAccessPolicy
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [switch] $StandaloneOnly,
        [switch] $DisableCache
    )

    Write-Verbose -Message 'Reading standalone Conditional Access policies and effective plan rules.'
    $policies = @(Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/policies' -ApiVersion beta -DisableCache:$DisableCache -ErrorAction Stop)
    if ($StandaloneOnly) { return $policies }

    $effectiveRules = [System.Collections.Generic.List[object]]::new()
    foreach ($plan in @(Get-MtConditionalAccessPolicyPlan -DisableCache:$DisableCache -ErrorAction Stop)) {
        foreach ($rule in @($plan.rules)) {
            $effectiveRules.Add((ConvertTo-MtConditionalAccessPolicy -Plan $plan -Rule $rule))
        }
    }
    return @($policies) + @($effectiveRules.ToArray())
}
