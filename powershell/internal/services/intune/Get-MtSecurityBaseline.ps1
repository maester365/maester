function Get-MtSecurityBaseline {
    <#
    .SYNOPSIS
    Retrieves Intune security baselines with the device-state summary Intune reports for each.

    .DESCRIPTION
    Lists the security baseline templates in the tenant (beta deviceManagement/templates, templateType
    'securityBaseline') and, for each, reads its device-state summary. It returns a normalized object per
    baseline carrying the display name and the per-state device counts (secure, not secure, conflict,
    error, unknown and not applicable), plus the total number of devices reporting against it.

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

    # -NoEnumerate keeps an empty list from collapsing to $null.
    Write-Output $result -NoEnumerate
}
