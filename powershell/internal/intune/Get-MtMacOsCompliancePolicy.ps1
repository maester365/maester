function Get-MtMacOsCompliancePolicy {
    <#
    .SYNOPSIS
    Retrieves macOS device compliance policies with their assignment state.

    .DESCRIPTION
    Queries Intune device compliance policies, filters to macOS policies, and returns a
    normalized object per policy carrying the display name, the assignment count and the
    settings evaluated by the macOS compliance checks.

    Assignment state is included because a compliance policy that is not assigned to any
    group is never evaluated against a device, so it cannot satisfy a security control.

    Returns $null when the compliance policies could not be read at all, so that callers can
    report a skip rather than a failure. The populated result is emitted with -NoEnumerate
    because PowerShell unrolls collections on output: an empty list would otherwise arrive at
    the caller as $null and be indistinguishable from a read failure. This matters because Invoke-MtGraphRequest surfaces a
    failed call as a non-terminating error with a null result, which collects as a single empty
    element. Treating that as "no policies exist" would produce a false negative: a security
    finding reported purely because the signed-in account lacked permission.

    Used by Test-MtMacOsSystemIntegrityProtection, Test-MtMacOsGatekeeper and
    Test-MtMacOsDefenderRiskScore.

    .EXAMPLE
    Get-MtMacOsCompliancePolicy

    Returns the macOS compliance policies configured in the tenant.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param()

    $policies = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/deviceCompliancePolicies' `
            -ApiVersion beta -QueryParameters @{ expand = 'assignments' } -ErrorAction Stop)

    # A failed request yields elements with no id. Distinguish that from an empty tenant.
    $usable = @($policies | Where-Object { $_ -and $_.id })
    if ($policies.Count -gt 0 -and $usable.Count -eq 0) {
        Write-Verbose "Compliance policies could not be read; returning null so the caller reports a skip."
        return $null
    }

    $macOsPolicies = @($usable | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.macOSCompliancePolicy' })

    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($policy in $macOsPolicies) {
        $assignmentCount = @($policy.assignments).Count
        $result.Add([pscustomobject]@{
                Id                       = $policy.id
                Name                     = $policy.displayName
                AssignmentCount          = $assignmentCount
                IsAssigned               = ($assignmentCount -gt 0)
                RequiresSip              = ($policy.systemIntegrityProtectionEnabled -eq $true)
                GatekeeperAllowedSource  = $policy.gatekeeperAllowedAppSource
                DefenderRiskScoreLevel   = $policy.advancedThreatProtectionRequiredSecurityLevel
                RequiresThreatProtection = ($policy.deviceThreatProtectionEnabled -eq $true)
            })
    }

    # -NoEnumerate keeps an empty list from collapsing to $null.
    Write-Output $result -NoEnumerate
}
