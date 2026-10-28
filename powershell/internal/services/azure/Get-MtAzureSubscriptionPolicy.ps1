function Get-MtAzureSubscriptionPolicy {
    <#
    .SYNOPSIS
    Returns the tenant's Azure subscription policy.

    .DESCRIPTION
    Retrieves the default subscription policy from the Azure Management API.
    The policy controls whether subscriptions can be transferred out of the tenant.

    .EXAMPLE
    Get-MtAzureSubscriptionPolicy

    Returns the subscription policy for the tenant.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Invoke-MtAzureRequest returns $null on 401/403; other failures throw and are reported by the engine.
    Invoke-MtAzureRequest `
        -RelativeUri '/providers/Microsoft.Subscription/policies/default' `
        -ApiVersion '2021-10-01'
}
