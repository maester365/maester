function Test-MtMacOSGatekeeper {
    <#
    .SYNOPSIS
    Ensure at least one assigned macOS compliance policy restricts where apps may be downloaded from.

    .DESCRIPTION
    Gatekeeper is the macOS control that decides which app download locations are permitted. It has
    three meaningful states, exposed by Intune compliance policy as gatekeeperAllowedAppSource:

    - macAppStore - only App Store apps may run. The most restrictive option.
    - macAppStoreAndIdentifiedDevelopers - App Store apps plus apps signed by a developer whose
      identity Apple has verified and notarized. The practical baseline for most organizations.
    - anywhere - any app from any source may run, including unsigned binaries. This is the least
      secure setting and Apple removed it from the macOS user interface for good reason.

    When the setting is left as notConfigured, Gatekeeper has no effect on the compliance verdict,
    so a device whose user has allowed apps from anywhere is still reported as compliant.

    Unrestricted app sources are a direct initial-access path: unsigned or ad-hoc signed binaries
    delivered by phishing or a drive-by download execute without Gatekeeper objection, which is how
    macOS infostealers are commonly installed.

    This test passes if at least one assigned macOS compliance policy sets the allowed app source to
    macAppStore or macAppStoreAndIdentifiedDevelopers. A policy set to anywhere or left unconfigured
    does not count.

    .EXAMPLE
    Test-MtMacOSGatekeeper

    Returns true if at least one assigned macOS compliance policy restricts app download locations.

    .LINK
    https://maester.dev/docs/commands/Test-MtMacOSGatekeeper
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose "Querying macOS compliance policies..."
        $policies = Get-MtMacOSCompliancePolicy
        if ($null -eq $policies) {
            # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }


        if ($policies.Count -eq 0) {
            $testResultMarkdown = "No macOS compliance policies were found in Intune.`n`n"
            $testResultMarkdown += "Without a macOS compliance policy, a Mac configured to allow apps from anywhere is still reported as compliant. "
            $testResultMarkdown += "Create a macOS compliance policy and set **Allow apps downloaded from these locations** to "
            $testResultMarkdown += "**Mac App Store and identified developers** or stricter."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # Friendly labels for the macOSGatekeeperAppSources enum.
        $sourceLabels = @{
            'notConfigured'                      = 'Not configured'
            'macAppStore'                        = 'Mac App Store only'
            'macAppStoreAndIdentifiedDevelopers' = 'App Store and identified developers'
            'anywhere'                           = 'Anywhere'
        }
        $acceptableSources = @('macAppStore', 'macAppStoreAndIdentifiedDevelopers')

        $compliant = @($policies | Where-Object { $_.IsAssigned -and $acceptableSources -contains $_.GatekeeperAllowedSource })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) macOS compliance policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Allowed app source | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $source = $policy.GatekeeperAllowedSource
            # Fall back to the raw value for anything unrecognised. Graph enums gain
            # values over time, and calling a real-but-unknown setting "Not configured"
            # would hide it from the reader.
            $sourceLabel = if ([string]::IsNullOrWhiteSpace($source)) {
                'Not configured'
            } elseif ($sourceLabels.ContainsKey($source)) {
                $sourceLabels[$source]
            } else {
                $source
            }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $sourceLabel | $assignmentState |`n"
        }


        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned macOS compliance policy restricts where apps may be downloaded from."
            $permissive = @($policies | Where-Object { $_.IsAssigned -and $_.GatekeeperAllowedSource -eq 'anywhere' })
            if ($permissive.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Warning:** $($permissive.Count) assigned policy/policies allow apps from **anywhere**, "
                $testResultMarkdown += "which permits unsigned binaries to run on devices scoped to them."
            }
        } else {
            $testResultMarkdown += "`nNo assigned macOS compliance policy restricts app download locations. "
            $testResultMarkdown += "Set **Allow apps downloaded from these locations** to **Mac App Store and identified developers** or stricter, "
            $testResultMarkdown += "and assign the policy to your macOS groups."
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }
}
