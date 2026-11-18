function Get-MtActivityBasedTimeout {
    <#
    .SYNOPSIS
        Returns the web session idle timeout that the tenant's activity-based timeout policy sets.

    .DESCRIPTION
        The idle session timeout in the Microsoft 365 admin center (Settings > Org settings > Security & privacy >
        Idle session timeout) is stored as an activity-based timeout policy in Microsoft Entra ID. Its definition is a
        JSON string whose WebSessionIdleTimeout value is a time span, such as 03:00:00.

        Returns an object with Timeout (a [timespan], or $null when no policy sets a timeout) and PolicyName (the
        display name of the policy that was read, or $null when there is none).

    .EXAMPLE
        (Get-MtActivityBasedTimeout).Timeout

        Returns the idle timeout as a time span, or $null when none is set.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param ()

    $policies = @(Invoke-MtGraphRequest -RelativeUri 'policies/activityBasedTimeoutPolicies' | Where-Object { $_ })

    $timeout = $null
    $policyName = $null
    if ($policies.Count -gt 0) {
        $policyName = $policies[0].displayName
        $definition = @($policies[0].definition)[0] | ConvertFrom-Json
        $value = $definition.ActivityBasedTimeoutPolicy.ApplicationPolicies[0].WebSessionIdleTimeout
        if ($value) {
            $timeout = [timespan]::Parse($value)
        }
    }

    [pscustomobject]@{
        Timeout    = $timeout
        PolicyName = $policyName
    }
}
