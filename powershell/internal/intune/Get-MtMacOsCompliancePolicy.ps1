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
            -ApiVersion beta -QueryParameters @{ expand = 'assignments' })

    $macOsPolicies = @($policies | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.macOSCompliancePolicy' })

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

    return $result
}
