function Get-MtIntuneSecurityBaselineInstance {
    <#
    .SYNOPSIS
    Returns one MT.1254 instance per assigned Intune security baseline.

    .DESCRIPTION
    Instance source of the MT.1254 family. The suffix is the security baseline's template ID
    (MT.1254.<templateId>) and the title names the baseline. Only baselines that are actually deployed to
    devices are emitted: a baseline template with no reporting device is not an assigned baseline and must
    not surface as a passing result.

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
    # Same shape as MT.1253 in this pull request.
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
        # Only baselines reporting against at least one device. An undeployed template has no outcome to
        # judge, so leaving it out keeps it from surfacing as a (false) passing baseline.
        if ($baseline.TotalDeviceCount -le 0) { continue }
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

    It runs once per assigned security baseline (deviceManagement/templates of type securityBaseline that
    report against at least one device). For each, Intune summarises its devices as secure, not secure,
    in conflict, in error, unknown or not applicable. The baseline passes when every device Intune has
    evaluated against it is secure, and fails when any device is not secure, in conflict, or in error.

    A baseline that is assigned but has no evaluated device yet (every device still unknown or not
    applicable) is skipped as not applicable: a baseline nothing has reported a secure-or-not verdict on
    is not a compliant baseline.

    .EXAMPLE
    Test-MtIntuneSecurityBaselineStatus

    Returns one result per assigned security baseline, true when every evaluated device is secure.

    .LINK
    https://maester.dev/docs/commands/Test-MtIntuneSecurityBaselineStatus
    #>
    [MaesterTest(
        Id = 'MT.1254',
        Title = 'Devices assigned a security baseline should comply with it.',
        Product = 'intune',
        Feature = 'endpoint-security',
        Area = 'devices',
        ResourceType = 'Policy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Lifecycle = 'Preview',
        Service = 'Graph',
        License = 'INTUNE_A',
        InstanceSource = 'Get-MtIntuneSecurityBaselineInstance',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The baseline to check, supplied by the engine.
        $Instance
    )

    $baseline = $Instance.Data
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
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $deviatingCount = $notSecureCount + $conflictCount + $errorCount
    $testResult = $deviatingCount -eq 0

    $testResultMarkdown = "Security baseline **$($baseline.Name)** is reporting against $($baseline.TotalDeviceCount) device(s).`n`n"
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
