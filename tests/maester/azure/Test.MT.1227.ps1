function Test-MtSubscriptionTransferBlocked {
    <#
    .SYNOPSIS
    Checks whether Azure subscriptions are blocked from leaving and entering the tenant.

    .DESCRIPTION
    Checks the tenant-level Azure subscription policy. Allowing subscriptions to leave
    the tenant can let a privileged user transfer their resources to an external tenant.
    Allowing subscriptions to enter the tenant can let a user bring in a subscription
    they control from another tenant.
    #>
    [MaesterTest(
        Id                 = 'MT.1227',
        Title              = 'Subscriptions should be blocked from leaving and entering the tenant',
        Product            = 'azure',
        Feature            = 'subscriptions',
        Area               = 'infrastructure',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1537',
        Control            = 'nist-800-53-r5:AC-4',
        Service            = 'Azure',
        Author             = 'Oppedijk',
        Contributor        = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-MtAzureSubscriptionPolicy

    if ($null -eq $policy) {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }

    $errorCode = if ($policy.error) { $policy.error.code } else { $policy.code }

    if ($errorCode -eq 'TenantPolicyNotFound') {
        # Since 1 May 2026 a tenant without an explicit policy blocks transfers in both directions.
        Add-MtTestResultDetail -Result 'Well done. No tenant subscription policy is set, so the Microsoft default blocks subscriptions from leaving and entering the tenant.'
        return $true
    }

    if ($errorCode) {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError ($policy | ConvertTo-Json -Depth 5)
        return $null
    }

    $blockLeaving = $policy.properties.blockSubscriptionsLeavingTenant -eq $true
    $blockEntering = $policy.properties.blockSubscriptionsIntoTenant -eq $true
    $testResult = $blockLeaving -and $blockEntering

    if ($testResult) {
        $testResultMarkdown = 'Well done. The tenant subscription policy blocks subscriptions from leaving and entering the tenant.'
    } else {
        $testResultMarkdown = "The tenant subscription policy allows subscriptions to move into or out of the tenant.`n`n"
        $testResultMarkdown += "| Setting | Value |`n| --- | --- |`n"
        $testResultMarkdown += "| Subscription leaving Microsoft Entra tenant | $(if ($blockLeaving) { '✅ Permit no one' } else { '❌ Allow everyone' }) |`n"
        $testResultMarkdown += "| Subscription entering Microsoft Entra tenant | $(if ($blockEntering) { '✅ Permit no one' } else { '❌ Allow everyone' }) |"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
