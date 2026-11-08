function Test-MtDefenderExploitableSoftwareVulnerability {
    <#
    .SYNOPSIS
    Ensure no device runs software with a high or critical vulnerability for which exploit code is
    publicly available.

    .DESCRIPTION
    Defender Vulnerability Management knows both the vulnerabilities present on each device and, from
    its vulnerability knowledge base, whether exploit code for a vulnerability is publicly available.
    The intersection is the part of the fleet an attacker can act on today with code they do not have to
    write.

    This check fails when any onboarded device runs software with a high or critical vulnerability whose
    IsExploitAvailable is true in DeviceTvmSoftwareVulnerabilitiesKB.

    On the signal used: the advanced hunting schema exposes no CISA KEV flag. IsExploitAvailable,
    documented as "whether exploit code for the vulnerability is publicly available", is the closest
    first-party signal, and it is what this check reports. It does not claim CISA KEV membership.

    The check does not pass on an unassessed fleet. It carries the number of distinct devices Defender
    has any vulnerability data for as a denominator; when that is zero, no device is onboarded to
    Defender for Endpoint or none has reported, and the result is skipped as not applicable. Zero
    exposed devices out of zero assessed devices is not a pass.

    .OUTPUTS
    [bool] - True when no assessed device is exposed, false when any is, null when skipped.

    .EXAMPLE
    Test-MtDefenderExploitableSoftwareVulnerability

    Returns true if no assessed device runs software with a publicly exploitable high or critical
    vulnerability.

    .LINK
    https://maester.dev/docs/commands/Test-MtDefenderExploitableSoftwareVulnerability
    #>
    # On Mitre: not T1190, which is about exploiting a public-facing application - this check
    # never establishes that anything is reachable from outside, so it would misclassify a
    # fleet of internal or client software. T1203 is what patching this software actually
    # prevents on an endpoint. 'None' was wrong too: the attribute review reads the
    # description as naming attacker behaviour, which it does.
    [MaesterTest(
        Id = 'MT.1270',
        Title = 'Devices should not run software with a publicly exploitable high or critical vulnerability.',
        Product = 'defender',
        Feature = 'exposure-management',
        Area = 'devices',
        ResourceType = 'Device',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1203',
        Service = 'Graph',
        License = 'DEFENDER_XDR',
        Lifecycle = 'Preview',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $summary = Get-MtDefenderExploitableVulnerability
    if ($null -eq $summary) {
        # Defender returned no result set at all. Report a skip rather than a clean fleet.
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    if ($summary.AssessedDeviceCount -le 0) {
        # No device has any vulnerability data, so there is no fleet to judge. Zero exposed out of zero
        # assessed is not a pass.
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $testResult = $summary.ExposedDeviceCount -eq 0
    $share = [math]::Round(($summary.ExposedDeviceCount / $summary.AssessedDeviceCount) * 100, 1)

    $testResultMarkdown = "Defender Vulnerability Management has data for **$($summary.AssessedDeviceCount)** device(s). "
    if ($testResult) {
        $testResultMarkdown += "None of them runs software with a publicly exploitable high or critical vulnerability.`n`n"
        $testResultMarkdown += "Well done. There is nothing an attacker can act on with published exploit code on this fleet today."
    } else {
        $testResultMarkdown += "**$($summary.ExposedDeviceCount)** of them ($share%) run software with a publicly exploitable high or critical vulnerability, across **$($summary.CveCount)** distinct CVE(s).`n`n"
        $testResultMarkdown += "| Property | Value |`n| --- | --- |`n"
        $testResultMarkdown += "| Assessed devices | $($summary.AssessedDeviceCount) |`n"
        $testResultMarkdown += "| Exposed devices | $($summary.ExposedDeviceCount) |`n"
        $testResultMarkdown += "| Distinct CVEs | $($summary.CveCount) |`n"

        $cve = @($summary.TopCveList | Where-Object { $_ })
        if ($cve.Count -gt 0) {
            $testResultMarkdown += "`nCVEs (up to ten shown): $($cve -join ', ')`n"
        }
        $software = @($summary.TopSoftwareList | Where-Object { $_ })
        if ($software.Count -gt 0) {
            # Software names come from the tenant's inventory, so they are escaped before they
            # reach Markdown: a name carrying link syntax would otherwise render as a link.
            $safeSoftware = @($software | ForEach-Object { Get-MtSafeMarkdown $_ })
            $testResultMarkdown += "`nSoftware (up to ten shown): $($safeSoftware -join ', ')`n"
        }
        $devices = @($summary.TopDeviceList | Where-Object { $_ })
        if ($devices.Count -gt 0) {
            # Device names are tenant-controlled too.
            $safeDevices = @($devices | ForEach-Object { Get-MtSafeMarkdown $_ })
            $testResultMarkdown += "`nDevices (up to ten shown): $($safeDevices -join ', ')`n"
        }

        $testResultMarkdown += "`nPatch or remove the software listed. Exploit code for these vulnerabilities is already public, so the window between disclosure and attack has closed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
