function Test-MtSubscriptionLeavingTenantBlocked {
    <#
    .SYNOPSIS
    Checks whether Azure subscriptions are blocked from leaving the tenant.

    .DESCRIPTION
    Checks the tenant-level Azure subscription policy. Allowing subscriptions to leave
    the tenant can let a privileged user transfer their resources to an external tenant.
    #>
    [MaesterTest(
        Id                 = 'MT.1226',
        Title              = 'Subscriptions should be blocked from leaving the tenant',
        Product            = 'azure',
        Feature            = 'subscriptions',
        Area               = 'access-control',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1537',
        Control            = 'nist-800-53-r5:AC-3',
        Service            = 'Azure',
        Author             = 'Oppedijk'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-MtAzureSubscriptionPolicy
    $policyNotFound = $policy.code -eq 'TenantPolicyNotFound' -or
        $policy.error.code -eq 'TenantPolicyNotFound'

    if ($policyNotFound) {
        $testResult = $false
        $testResultMarkdown = 'No tenant subscription policy is assigned. Enable the policy to prevent subscriptions from leaving the tenant.'
    } else {
        $testResult = $policy.properties.blockSubscriptionsLeavingTenant -eq $true

        if ($testResult) {
            $testResultMarkdown = 'Well done. The tenant subscription policy blocks subscriptions from leaving the tenant without authorization.'
        } else {
            $testResultMarkdown = 'The tenant subscription policy does not block subscriptions from leaving the tenant. Enable blockSubscriptionsLeavingTenant to prevent unauthorized transfers.'
        }
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}