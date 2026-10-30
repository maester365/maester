function Test-MtAsdWorkstationPatchDeadline {
    <#
    .SYNOPSIS
    Checks that an assigned Intune Windows update ring installs quality updates on workstations within one month of release.

    .DESCRIPTION
    ISM-1695 (Essential Eight, Patch operating systems, Maturity Level One) asks that patches, updates or other
    vendor mitigations for vulnerabilities in the operating systems of workstations are applied within one
    month of release.

    The check reads the Windows update rings in Intune. A ring satisfies the control when it is assigned, does
    not pause quality updates, sets a deadline for quality updates, and the deferral period, the deadline and
    the grace period add up to no more than the maximum number of days (30 by default). Rings that use
    Windows Autopatch, or devices updated by another tool, are not read.

    .EXAMPLE
    Test-MtAsdWorkstationPatchDeadline

    Returns true when at least one assigned update ring installs quality updates within 30 days of release.

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
        # The most days a quality update may take from release to forced installation: deferral, deadline and grace period together.
        [ValidateRange(1, 365)]
        [int] $MaximumDays = 30
    )

    $rings = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')&`$expand=assignments" -ApiVersion beta)
    if ($rings.Count -eq 0) {
        Add-MtTestResultDetail -Result 'No Windows update ring exists in Intune. Create one under Devices > Windows > Update rings for Windows 10 and later, with a deadline for quality updates, and assign it to your workstations.'
        return $false
    }

    $report = foreach ($ring in $rings) {
        $deferral = [int]$ring.qualityUpdatesDeferralPeriodInDays
        $deadline = $ring.deadlineForQualityUpdatesInDays
        $grace = [int]$ring.deadlineGracePeriodInDays
        $total = if ($null -ne $deadline) { $deferral + [int]$deadline + $grace } else { $null }
        [pscustomobject]@{
            Name       = $ring.displayName
            Assigned   = @($ring.assignments).Count -gt 0
            Paused     = $ring.qualityUpdatesPaused -eq $true
            Deferral   = $deferral
            Deadline   = $deadline
            Grace      = $grace
            TotalDays  = $total
            Compliant  = @($ring.assignments).Count -gt 0 -and $ring.qualityUpdatesPaused -ne $true -and $null -ne $total -and $total -le $MaximumDays
        }
    }
    $testResult = @($report | Where-Object Compliant).Count -gt 0

    $table = "| Update ring | Assigned | Quality updates paused | Deferral | Deadline | Grace period | Days to install |`n| --- | --- | --- | --- | --- | --- | --- |`n"
    foreach ($r in $report) {
        $table += "| $($r.Name) | $(if ($r.Assigned) { 'Yes' } else { 'No' }) | $(if ($r.Paused) { 'Yes' } else { 'No' }) | $($r.Deferral) | $(if ($null -ne $r.Deadline) { $r.Deadline } else { 'Not set' }) | $($r.Grace) | $(if ($null -ne $r.TotalDays) { $r.TotalDays } else { 'No deadline' }) |`n"
    }
    if ($testResult) {
        $testResultMarkdown = "Well done. At least one assigned update ring installs quality updates within $MaximumDays days of release.`n`n$table"
    } else {
        $testResultMarkdown = "No assigned update ring installs quality updates within $MaximumDays days of release. Set a deadline for quality updates so that deferral, deadline and grace period add up to $MaximumDays days or fewer.`n`n$table"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
