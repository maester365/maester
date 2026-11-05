function Test-MtAsdWorkstationPatchDeadline {
    <#
    .SYNOPSIS
    Checks the configured quality-update deadline of Intune Windows update rings.

    .DESCRIPTION
    ISM-1695 (Essential Eight, Patch operating systems, Maturity Level One) asks that patches, updates or other
    vendor mitigations for vulnerabilities in the operating systems of workstations are applied within one
    month of release.

    The check reads the Windows update rings in Intune. It passes when a ring has an inclusion assignment, does
    not pause quality updates, sets a deadline for quality updates, and the deferral period, the deadline and
    the grace period add up to no more than the maximum number of days (30 by default). It does not verify
    assignment scope or the time between an update's release and installation. Rings that use Windows Autopatch,
    or devices updated by another tool, are not read.

    .EXAMPLE
    Test-MtAsdWorkstationPatchDeadline

    Returns true when at least one update ring with an inclusion assignment has a configured total of 30 days or less.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1695
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1695',
        Title = 'Patches for vulnerabilities in the operating systems of workstations are applied within one month of release.',
        Product = 'intune',
        Feature = 'device-configuration',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1203', 'T1068'),
        Control = ('essential-eight:ISM-1695', 'nist-800-53-r5:SI-2(3)'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The maximum configured total of the deferral, deadline and grace periods.
        [ValidateRange(1, 365)]
        [int] $MaximumDays = 30
    )

    $rings = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')&`$expand=assignments" -ApiVersion beta)
    if ($rings.Count -eq 0) {
        Add-MtTestResultDetail -Result 'No Windows update ring exists in Intune. Create one under Devices > Windows > Update rings for Windows 10 and later, with a deadline for quality updates, and assign it to your workstations.'
        return $false
    }

    $report = foreach ($ring in $rings) {
        $isAssigned = @($ring.assignments | Where-Object {
                $targetType = [string] $_.target.'@odata.type'
                $targetType -and $targetType -notmatch '(^|\.)exclusion'
            }).Count -gt 0
        $deferral = [int]$ring.qualityUpdatesDeferralPeriodInDays
        $deadline = $ring.deadlineForQualityUpdatesInDays
        $grace = [int]$ring.deadlineGracePeriodInDays
        $total = if ($null -ne $deadline) { $deferral + [int]$deadline + $grace } else { $null }
        [pscustomobject]@{
            Name       = $ring.displayName
            Assigned   = $isAssigned
            Paused     = $ring.qualityUpdatesPaused -eq $true
            Deferral   = $deferral
            Deadline   = $deadline
            Grace      = $grace
            TotalDays  = $total
            Compliant  = $isAssigned -and $ring.qualityUpdatesPaused -ne $true -and $null -ne $total -and $total -le $MaximumDays
        }
    }
    $testResult = @($report | Where-Object Compliant).Count -gt 0

    $table = "| Update ring | Inclusion assignment | Quality updates paused | Deferral | Deadline | Grace period | Configured total (days) |`n| --- | --- | --- | --- | --- | --- | --- |`n"
    foreach ($r in $report) {
        $table += "| $($r.Name) | $(if ($r.Assigned) { 'Yes' } else { 'No' }) | $(if ($r.Paused) { 'Yes' } else { 'No' }) | $($r.Deferral) | $(if ($null -ne $r.Deadline) { $r.Deadline } else { 'Not set' }) | $($r.Grace) | $(if ($null -ne $r.TotalDays) { $r.TotalDays } else { 'No deadline' }) |`n"
    }
    if ($testResult) {
        $testResultMarkdown = "At least one update ring with an inclusion assignment has a configured deferral, deadline and grace period totalling $MaximumDays days or fewer.`n`n$table"
    } else {
        $testResultMarkdown = "No update ring with an inclusion assignment has a quality-update deadline with deferral, deadline and grace period totalling $MaximumDays days or fewer. Set a deadline for quality updates and assign the ring to your workstations.`n`n$table"
    }
    $testResultMarkdown += "`n`nThis checks policy configuration and inclusion assignments; it does not verify assignment coverage or exclusions, conflicts, device discovery, or actual installation times after release."
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
