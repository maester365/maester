function Test-MtCaUntargetedPolicy {
    <#
    .Synopsis
    Checks if any Conditional Access policy is not targeted to any resource.

    .Description
    Neither the Entra admin center nor Microsoft Graph require a Conditional Access policy to
    target at least one resource (cloud apps, user actions, or authentication context). Such a
    policy is accepted, can be enabled, and appears like any other policy - but it applies to
    nothing and enforces nothing. This check also recognizes apps targeted dynamically through a
    custom security attribute filter, so it doesn't flag policies that are legitimately scoped that way.

    This gives a false sense of security: the policy looks like active protection, but has no effect.

    .Example
    Test-MtCaUntargetedPolicy

    Returns true if all Conditional Access policies target at least one resource.

    .LINK
    https://maester.dev/docs/commands/Test-MtCaUntargetedPolicy
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Checking if any Conditional Access policy is not targeted to any resource...'
    try {
        $policies = Get-MtConditionalAccessPolicy

        $untargetedPolicies = $policies | Where-Object {
            $applications = $_.conditions.applications
            $hasApplications = ( $applications.includeApplications | Where-Object { $_ -and $_ -ne 'None' } | Measure-Object ).Count -gt 0
            $hasUserActions = ( $applications.includeUserActions | Measure-Object ).Count -gt 0
            $hasAuthContext = ( $applications.includeAuthenticationContextClassReferences | Measure-Object ).Count -gt 0
            $hasApplicationFilter = $null -ne $applications.applicationFilter

            -not ( $hasApplications -or $hasUserActions -or $hasAuthContext -or $hasApplicationFilter )
        }

        $result = ( $untargetedPolicies | Measure-Object ).Count -eq 0

        if ($result) {
            $testResult = 'Well done! All Conditional Access policies are targeted to at least one resource (cloud apps/resources, user actions, or authentication context).'
        } else {
            $testResult = "These Conditional Access policies aren't targeted to any resource, so they have no effect even if enabled:`n`n"
            $testResult += Get-GraphObjectMarkdown -GraphObjects $untargetedPolicies -GraphObjectType ConditionalAccess
            $testResult += "`n`nOpen each policy and either configure a target under **Target resources** (cloud apps/resources, user actions, or authentication context) or delete the policy if it's no longer needed."
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
