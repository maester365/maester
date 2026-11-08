function Test-MtIntuneDeviceComplianceStatus {
    <#
    .SYNOPSIS
    Ensure the share of non-compliant Intune managed devices stays below a configured threshold.

    .DESCRIPTION
    Maester's other Intune checks look at how compliance policies are configured. This check looks at the
    outcome Intune reports: of the devices Intune has actually evaluated, how many are non-compliant.

    A device's complianceState is one of compliant, noncompliant, conflict, error, inGracePeriod, unknown
    or configManager. This test counts a device as non-compliant when it is noncompliant, in conflict,
    in error, or in the grace period (which is non-compliant but still has access). It leaves unknown and
    configManager devices out of the calculation: an unknown device has not reported a verdict, and a
    configManager device is evaluated by Configuration Manager, not Intune.

    The test passes when the non-compliant share of evaluated devices is at or below the threshold, which
    defaults to 5% and can be set per tenant. It fails when the share is above the threshold.

    It does not pass when Intune has no managed devices, or when no device has reported a verdict yet: a
    tenant with nothing to measure is skipped as not applicable, never reported as compliant. A share of
    zero over zero devices is not a pass.

    .EXAMPLE
    Test-MtIntuneDeviceComplianceStatus

    Returns true if the non-compliant share of evaluated Intune managed devices is at or below 5%.

    .EXAMPLE
    Test-MtIntuneDeviceComplianceStatus -MaxNonCompliantPercentage 10

    Returns true if the non-compliant share of evaluated Intune managed devices is at or below 10%.

    .LINK
    https://maester.dev/docs/commands/Test-MtIntuneDeviceComplianceStatus
    #>
    [MaesterTest(
        Id = 'MT.1267',
        Title = 'Non-compliant Intune managed devices should be below the configured threshold.',
        Product = 'intune',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Device',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Lifecycle = 'Preview',
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The highest share of evaluated devices that may be non-compliant before this test fails, as a
        # percentage. Set it per tenant in maester-config.json (TestSettings > Parameters).
        [ValidateRange(0, 100)]
        [int] $MaxNonCompliantPercentage = 5
    )

    Write-Verbose "Querying Intune managed devices..."

    # Only the retrieval is guarded. A 401/403 from Intune RBAC is a missing permission, which is a
    # skip; anything else is left to surface as an error, so a real defect in this test is never
    # reported as a skip.
    try {
        $devices = Get-MtManagedDeviceCompliance
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    if ($null -eq $devices) {
        # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
        # Report a skip rather than a false result.
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }

    # States that carry a compliance verdict. unknown has not reported one, and configManager devices
    # are evaluated by Configuration Manager, so both are left out of the share.
    $evaluatedStates = @('compliant', 'noncompliant', 'conflict', 'error', 'ingraceperiod')
    $nonCompliantStates = @('noncompliant', 'conflict', 'error', 'ingraceperiod')

    $evaluated = @($devices | Where-Object { $_.ComplianceState -in $evaluatedStates })
    if ($evaluated.Count -eq 0) {
        # Nothing to measure. A share of zero non-compliant over zero evaluated devices is not a pass:
        # skip as not applicable so an empty or not-yet-reported tenant is never reported as compliant.
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $nonCompliant = @($devices | Where-Object { $_.ComplianceState -in $nonCompliantStates })
    $percentage = [math]::Round(($nonCompliant.Count / $evaluated.Count) * 100, 1)
    $testResult = $percentage -le $MaxNonCompliantPercentage

    $counts = [ordered]@{
        'Compliant'      = @($devices | Where-Object { $_.ComplianceState -eq 'compliant' }).Count
        'Non-compliant'  = @($devices | Where-Object { $_.ComplianceState -eq 'noncompliant' }).Count
        'In grace period' = @($devices | Where-Object { $_.ComplianceState -eq 'ingraceperiod' }).Count
        'Conflict'       = @($devices | Where-Object { $_.ComplianceState -eq 'conflict' }).Count
        'Error'          = @($devices | Where-Object { $_.ComplianceState -eq 'error' }).Count
        'Unknown (not counted)'        = @($devices | Where-Object { $_.ComplianceState -eq 'unknown' }).Count
        'Config Manager (not counted)' = @($devices | Where-Object { $_.ComplianceState -eq 'configmanager' }).Count
    }

    $testResultMarkdown = "Evaluated $($evaluated.Count) of $($devices.Count) managed device(s). "
    $testResultMarkdown += "**$($nonCompliant.Count)** ($percentage%) are non-compliant; the threshold is $MaxNonCompliantPercentage%.`n`n"
    $testResultMarkdown += "| Compliance state | Devices |`n"
    $testResultMarkdown += "| --- | --- |`n"
    foreach ($state in $counts.Keys) {
        $testResultMarkdown += "| $state | $($counts[$state]) |`n"
    }

    if ($testResult) {
        $testResultMarkdown += "`nWell done. The non-compliant share is at or below the threshold."
    } else {
        $testResultMarkdown += "`nThe non-compliant share is above the threshold. Review the non-compliant devices in Intune and bring them back into compliance, or investigate why they cannot report as compliant."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
