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

    try
    {
        $policy = Invoke-MtAzureRequest `
            -RelativeUri '/providers/Microsoft.Subscription/policies/default' `
            -ApiVersion '2021-10-01'
    }
    catch {
        Write-Verbose "Error retrieving subscription policy: $_"
        return $null
    }

    return $policy
}