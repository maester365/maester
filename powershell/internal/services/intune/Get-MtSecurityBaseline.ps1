function Get-MtSecurityBaseline {
    <#
    .SYNOPSIS
    Retrieves Intune security baselines with the device-state summary Intune reports for each.

    .DESCRIPTION
    Lists the security baselines in the tenant, of both kinds, and returns a normalized object per
    baseline carrying a Kind and the display name.

    Kind 'Template' is a legacy baseline (beta deviceManagement/templates, templateType
    'securityBaseline'). For each, this reads its device-state summary and carries the per-state device
    counts (secure, not secure, conflict, error, unknown and not applicable), plus the total number of
    devices reporting against it.

    Kind 'SettingsCatalog' is a current baseline (beta deviceManagement/configurationPolicies whose
    templateReference/templateFamily is 'baseline'). These carry an AssignmentCount and no device counts,
    because Intune publishes no per-device compliance summary for them through a documented API:
    configurationPolicies has no deviceStatuses navigation, and the only route is the
    DeviceStatusesByConfigurationProfile export, whose column *values* are undocumented. The caller
    reports those baselines rather than judging them. Without this family a tenant whose baselines are
    all current ones reports that there is nothing to check, which is the opposite of the truth.

    The total is included because a baseline template that no device reports against is not deployed to
    anything, so it cannot have a compliance outcome. The caller uses the total to leave undeployed
    baselines out, rather than reporting a pass for a baseline no device follows.

    Returns $null when the baseline templates could not be read at all, so that callers can report a skip
    rather than a failure. The populated result is emitted with -NoEnumerate because PowerShell unrolls
    collections on output: an empty list would otherwise arrive at the caller as $null and be
    indistinguishable from a read failure. Invoke-MtGraphRequest surfaces a failed call as a
    non-terminating error with a null result, which collects as a single empty element; treating that as
    "no baselines exist" would hide a permission problem behind a clean result.

    A missing count is read as zero so that an undeployed baseline reports a total of zero and is left out,
    instead of throwing on an absent property.

    Errors are deliberately not caught here. The calling instance source skips the family on a read
    failure, so swallowing the exception at this level would lose the status code and turn a permission
    problem into a false result.

    .EXAMPLE
    Get-MtSecurityBaseline

    Returns the security baselines configured in the tenant with their device-state summary.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param()

    $templates = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/templates' -ApiVersion beta `
            -Filter "templateType eq 'securityBaseline'" -ErrorAction Stop)

    # A failed request yields elements with no id. Distinguish that from a tenant with no baselines.
    $usable = @($templates | Where-Object { $_ -and $_.id })
    if ($templates.Count -gt 0 -and $usable.Count -eq 0) {
        Write-Verbose "Security baseline templates could not be read; returning null so the caller reports a skip."
        return $null
    }

    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($template in $usable) {
        $summary = Invoke-MtGraphRequest -ApiVersion beta `
            -RelativeUri "deviceManagement/templates/$($template.id)/microsoft.graph.securityBaselineTemplate/deviceStateSummary" `
            -ErrorAction Stop

        $secureCount = [int]$summary.secureCount
        $notSecureCount = [int]$summary.notSecureCount
        $conflictCount = [int]$summary.conflictCount
        $errorCount = [int]$summary.errorCount
        $unknownCount = [int]$summary.unknownCount
        $notApplicableCount = [int]$summary.notApplicableCount

        $result.Add([pscustomobject]@{
                Kind               = 'Template'
                Id                 = $template.id
                Name               = $template.displayName
                SecureCount        = $secureCount
                NotSecureCount     = $notSecureCount
                ConflictCount      = $conflictCount
                ErrorCount         = $errorCount
                UnknownCount       = $unknownCount
                NotApplicableCount = $notApplicableCount
                TotalDeviceCount   = $secureCount + $notSecureCount + $conflictCount + $errorCount + $unknownCount + $notApplicableCount
            })
    }

    # The current baselines live in the settings catalog, under a templateReference whose templateFamily
    # is 'baseline' (a documented member of deviceManagementConfigurationTemplateFamily). Assignments are
    # expanded in the same request so that an unassigned baseline can be told from a deployed one without
    # a call per policy.
    $policies = @(Invoke-MtGraphRequest -ApiVersion beta -ErrorAction Stop `
            -RelativeUri "deviceManagement/configurationPolicies?`$filter=templateReference/templateFamily eq 'baseline'&`$expand=assignments")

    $usablePolicies = @($policies | Where-Object { $_ -and $_.id })
    if ($policies.Count -gt 0 -and $usablePolicies.Count -eq 0) {
        Write-Verbose "Settings catalog baselines could not be read; returning null so the caller reports a skip."
        return $null
    }

    foreach ($policy in $usablePolicies) {
        $result.Add([pscustomobject]@{
                Kind            = 'SettingsCatalog'
                Id              = $policy.id
                # configurationPolicies carries 'name', not 'displayName'.
                Name            = $policy.name
                AssignmentCount = @($policy.assignments | Where-Object { $_ }).Count
            })
    }

    # -NoEnumerate keeps an empty list from collapsing to $null.
    Write-Output $result -NoEnumerate
}
