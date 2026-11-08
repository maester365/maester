function ConvertTo-MtConditionalAccessPolicy {
    <#
    .SYNOPSIS
    Projects a plan rule into the policy shape used by Maester's Conditional Access checks.

    .DESCRIPTION
    Preserves the real rule ID, state, original rule conditions and controls. Exposes inherited effective conditions,
    grantControls and sessionControls at the same paths as a standalone policy, with explicit parent-plan metadata.
    Never mutates the cached plan or rule and never treats a plan owner as an administrator or a rule assignment.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $Plan,
        [Parameter(Mandatory)] [object] $Rule
    )

    if ([string]::IsNullOrWhiteSpace([string]$Plan.id) -or [string]::IsNullOrWhiteSpace([string]$Rule.id)) {
        throw 'Conditional Access plans and rules must have IDs before they can be evaluated.'
    }
    if ($Rule.state -notin @('enabled', 'disabled', 'enabledForReportingButNotEnforced')) {
        throw "Conditional Access rule '$($Rule.id)' has an unsupported state '$($Rule.state)'."
    }
    $parent = $Plan | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
    $copy = $Rule | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
    if (-not $copy.controls -or (-not $copy.controls.grantControls -and -not $copy.controls.sessionControls)) {
        throw "Conditional Access rule '$($Rule.id)' has no supported enforcement controls."
    }
    $copy['@odata.type'] = '#microsoft.graph.conditionalAccessPolicyRule'
    $copy['ruleConditions'] = $copy.conditions
    try {
        $copy['conditions'] = Merge-MtConditionalAccessCondition -Shared $parent.sharedConditions -Rule $copy.conditions
    } catch {
        throw "Cannot evaluate rule '$($Rule.id)' in plan '$($Plan.id)': $($_.Exception.Message)"
    }
    $copy['grantControls'] = $copy.controls.grantControls
    $copy['sessionControls'] = $copy.controls.sessionControls
    $copy['displayName'] = "[Plan: $($Plan.displayName)] [Rule: $($Rule.displayName)]"
    $copy['planId'] = $Plan.id
    $copy['planDisplayName'] = $Plan.displayName
    $copy['planOwners'] = @($Plan.owners)
    $copy['sharedConditions'] = $parent.sharedConditions
    $copy['sourceType'] = 'PolicyPlanRule'
    return [pscustomobject]$copy
}
