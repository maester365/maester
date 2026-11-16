function Get-MtIntuneSecurityBaselineInstance {
    <#
    .SYNOPSIS
    Returns one MT.1268 instance per assigned Intune security baseline.

    .DESCRIPTION
    Instance source of the MT.1268 family. The suffix is the security baseline's ID and the title names
    the baseline. Only baselines that are actually deployed are emitted: a baseline nothing has been
    given is not an assigned baseline and must not surface as a passing result.

    Both kinds of baseline are emitted. A legacy template counts as deployed when at least one device
    reports against it. A settings catalog baseline counts as deployed when it has at least one
    assignment, since Intune exposes no device count for it; the check then reports it rather than
    judging it. Leaving that kind out is what made a tenant whose baselines are all current ones report
    that there was nothing here to check.

    When the baselines cannot be read at all (typically a 403 from Intune RBAC) the whole family is
    skipped rather than reported, because Add-MtTestResultDetail -SkippedBecause in an instance source
    skips the family. When there are no assigned baselines the source emits nothing, and the engine skips
    the family with NoInstances; it is never a pass.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    # Only the retrieval is guarded, and only 401/403. The helper has two failure paths: it returns
    # $null when the response comes back with no usable ids, which the check below already covered,
    # and it lets a terminating error through, which did not reach that check and surfaced as
    # InstanceSourceFailed instead of the skip this function documents. Anything that is not a
    # permission problem is still left to surface, so a real defect is never reported as a skip.
    # Same shape as MT.1267 in this pull request.
    try {
        $baselines = Get-MtSecurityBaseline
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return
        }
        throw
    }

    if ($null -eq $baselines) {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return
    }

    foreach ($baseline in $baselines) {
        if ($baseline.Kind -eq 'SettingsCatalog') {
            # No device count exists for this kind, so deployment is read from the assignments. An
            # unassigned baseline is left out for the same reason an undeployed template is.
            if ([int]$baseline.AssignmentCount -le 0) { continue }
        } else {
            # Only baselines reporting against at least one device. An undeployed template has no outcome
            # to judge, so leaving it out keeps it from surfacing as a (false) passing baseline.
            if ($baseline.TotalDeviceCount -le 0) { continue }
        }

        [pscustomobject]@{
            Id    = $baseline.Id
            Title = "Security baseline '$($baseline.Name)' should report every device as secure."
            Data  = $baseline
        }
    }
}

function Test-MtIntuneSecurityBaselineStatus {
    <#
    .SYNOPSIS
    Ensure devices assigned a security baseline comply with it.

    .DESCRIPTION
    Maester's other Intune checks look at how policies are configured. This check looks at the outcome
    Intune reports for each assigned security baseline: whether the devices the baseline is deployed to
    actually match it.

    It runs once per assigned security baseline, of either kind.

    For a legacy baseline (deviceManagement/templates of type securityBaseline that reports against at
    least one device) Intune summarises its devices as secure, not secure, in conflict, in error, unknown
    or not applicable. The baseline passes when every device Intune has evaluated against it is secure,
    and fails when any device is not secure, in conflict, or in error.

    For a settings catalog baseline there is no such summary to read, so the baseline is reported and
    skipped with a reason that names the limitation rather than judged. The engine's NotApplicable text
    ("This test does not apply to this tenant.") said the opposite of the detail next to it, which states
    that the baseline is assigned. Graph publishes no per-device state for
    configurationPolicies - the resource has no deviceStatuses navigation, and the one route that carries
    it, the DeviceStatusesByConfigurationProfile export, documents its column names but not the meaning of
    their values. Deciding a tenant's security posture on an undocumented encoding is worse than saying
    plainly that the number is not available, and a silent pass would be worse than both: on a tenant
    whose only baseline sat in error, this family reported that there was nothing to check.

    A baseline that is assigned but has no evaluated device yet (every device still unknown or not
    applicable) is skipped with that as its stated reason: a baseline nothing has reported a
    secure-or-not verdict on is not a compliant baseline.

    .EXAMPLE
    Test-MtIntuneSecurityBaselineStatus

    Returns one result per assigned security baseline, true when every evaluated device is secure.

    .LINK
    https://maester.dev/docs/commands/Test-MtIntuneSecurityBaselineStatus
    #>
    [MaesterTest(
        Id = 'MT.1268',
        Title = 'Devices assigned a security baseline should comply with it.',
        Product = 'intune',
        Feature = 'endpoint-security',
        Area = 'devices',
        ResourceType = 'Policy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'Graph',
        License = 'INTUNE_A',
        Lifecycle = 'Preview',
        InstanceSource = 'Get-MtIntuneSecurityBaselineInstance',
        Author = 'earbona23',
        Contributor = ('julien-ly')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The baseline to check, supplied by the engine.
        $Instance
    )

    $baseline = $Instance.Data

    if ($baseline.Kind -eq 'SettingsCatalog') {
        $assignmentCount = [int]$baseline.AssignmentCount
        $markdown = "Security baseline **$(Get-MtSafeMarkdown $baseline.Name)** is a settings catalog baseline, assigned to $assignmentCount group(s) or filter(s).`n`n"
        $markdown += "Intune publishes no per-device compliance summary for a settings catalog baseline through a documented API, "
        $markdown += "so this test reports the baseline rather than giving it a verdict. "
        $markdown += "Check its device status in the Intune admin center under **Devices** > **Configuration**, or export "
        $markdown += "[DeviceStatusesByConfigurationProfile](https://learn.microsoft.com/intune/device-management/reports/ref-graph-available-reports#devicestatusesbyconfigurationprofile)."
        Add-MtTestResultDetail -Result $markdown -SkippedBecause Custom -SkippedCustomReason 'Intune publishes no per-device state for a settings catalog baseline, so this baseline is reported rather than judged.'
        return $null
    }

    $secureCount = [int]$baseline.SecureCount
    $notSecureCount = [int]$baseline.NotSecureCount
    $conflictCount = [int]$baseline.ConflictCount
    $errorCount = [int]$baseline.ErrorCount
    $unknownCount = [int]$baseline.UnknownCount
    $notApplicableCount = [int]$baseline.NotApplicableCount

    $evaluatedCount = $secureCount + $notSecureCount + $conflictCount + $errorCount
    if ($evaluatedCount -le 0) {
        # Assigned, but no device has reported a secure or not-secure verdict yet. There is no outcome to
        # judge, so skip rather than pass.
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'This baseline is assigned, but no device has reported a secure or not-secure verdict yet.'
        return $null
    }

    $deviatingCount = $notSecureCount + $conflictCount + $errorCount
    $testResult = $deviatingCount -eq 0

    $testResultMarkdown = "Security baseline **$(Get-MtSafeMarkdown $baseline.Name)** is reporting against $($baseline.TotalDeviceCount) device(s).`n`n"
    $testResultMarkdown += "| Device state | Devices |`n"
    $testResultMarkdown += "| --- | --- |`n"
    $testResultMarkdown += "| Secure | $secureCount |`n"
    $testResultMarkdown += "| Not secure | $notSecureCount |`n"
    $testResultMarkdown += "| Conflict | $conflictCount |`n"
    $testResultMarkdown += "| Error | $errorCount |`n"
    $testResultMarkdown += "| Unknown | $unknownCount |`n"
    $testResultMarkdown += "| Not applicable | $notApplicableCount |`n"

    if ($testResult) {
        $testResultMarkdown += "`nWell done. Every device evaluated against this baseline is secure."
    } else {
        $testResultMarkdown += "`n**$deviatingCount** of $evaluatedCount evaluated device(s) do not match this baseline. "
        $testResultMarkdown += "Review the baseline in Intune to see which setting each device deviates on, and remediate the devices or resolve the conflicting policy."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
