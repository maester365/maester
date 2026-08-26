function Test-MtMacOSGatekeeper {
    <#
    .SYNOPSIS
    Ensure macOS devices are restricted to trusted app download locations by Gatekeeper.

    .DESCRIPTION
    Gatekeeper decides which app download locations are permitted on macOS. Intune can address it two
    ways, and both count for this check:

    - A macOS compliance policy evaluates the device's current Gatekeeper state through
      gatekeeperAllowedAppSource and marks the device non-compliant if it is looser than required,
      which feeds Conditional Access. Acceptable values are macAppStore and
      macAppStoreAndIdentifiedDevelopers.
    - A macOS configuration policy pushes the com.apple.systempolicy.control payload, enforcing the
      setting on the device rather than merely observing it. The macOS endpoint protection template
      is deprecated, so this is authored in the settings catalog.

    Unrestricted app sources are a direct initial-access path. Unsigned or ad-hoc signed binaries
    delivered by phishing or a drive-by download execute without Gatekeeper objection, which is how
    macOS infostealers are routinely installed. Restricting the allowed source breaks that chain at
    execution.

    The check passes if at least one assigned policy of either kind restricts app sources. A
    compliance policy set to anywhere or left unconfigured does not count, and neither does a
    configuration policy that disables Gatekeeper assessment. Unassigned policies are reported but do
    not count towards a pass, because they are never applied or evaluated.

    .EXAMPLE
    Test-MtMacOSGatekeeper

    Returns true if at least one assigned policy restricts macOS app download locations.

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
        Write-Verbose "Querying macOS compliance policies and Gatekeeper configuration policies..."
        $compliancePolicies = Get-MtMacOSCompliancePolicy
        if ($null -eq $compliancePolicies) {
            # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        $enforcementPolicies = Get-MtMacOSGatekeeperEnforcement
        if ($null -eq $enforcementPolicies) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        if ($compliancePolicies.Count -eq 0 -and $enforcementPolicies.Count -eq 0) {
            $testResultMarkdown = "No macOS compliance policies or Gatekeeper configuration policies were found in Intune.`n`n"
            $testResultMarkdown += "A Mac configured to allow apps from anywhere is neither corrected nor reported as non-compliant. "
            $testResultMarkdown += "Set **Allow apps downloaded from these locations** to **Mac App Store and identified developers** in a "
            $testResultMarkdown += "macOS compliance policy, or enforce the **System Policy Control** payload from the settings catalog."
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

        $rows = [System.Collections.Generic.List[pscustomobject]]::new()

        foreach ($policy in $compliancePolicies) {
            $source = $policy.GatekeeperAllowedSource
            # Fall back to the raw value for anything unrecognised. Graph enums gain values over
            # time, and calling a real-but-unknown setting "Not configured" would hide it.
            $label = if ([string]::IsNullOrWhiteSpace($source)) {
                'Not configured'
            } elseif ($sourceLabels.ContainsKey($source)) {
                $sourceLabels[$source]
            } else {
                $source
            }
            $rows.Add([pscustomobject]@{
                    Name       = $policy.Name
                    Source     = 'Compliance policy'
                    Setting    = $label
                    IsAssigned = $policy.IsAssigned
                    Assignment = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
                    Restricts  = ($acceptableSources -contains $source)
                })
        }

        foreach ($policy in $enforcementPolicies) {
            if ($policy.AssessmentEnabled) {
                $label = if ($policy.AllowIdentifiedDevelopers) { 'Enforced: App Store and identified developers' } else { 'Enforced: Mac App Store only' }
            } else {
                $label = 'Enforced: Gatekeeper assessment disabled'
            }
            $rows.Add([pscustomobject]@{
                    Name       = $policy.Name
                    Source     = 'Settings catalog'
                    Setting    = $label
                    IsAssigned = $policy.IsAssigned
                    Assignment = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
                    Restricts  = $policy.AssessmentEnabled
                })
        }

        $compliant = @($rows | Where-Object { $_.IsAssigned -and $_.Restricts })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($rows.Count) macOS policy/policies affecting Gatekeeper in Intune.`n`n"
        $testResultMarkdown += "| Policy | Source | Allowed app source | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"
        foreach ($row in $rows) {
            $testResultMarkdown += "| $($row.Name) | $($row.Source) | $($row.Setting) | $($row.Assignment) |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned policy restricts where apps may be downloaded from."

            $permissive = @($rows | Where-Object { $_.IsAssigned -and -not $_.Restricts -and $_.Setting -in @('Anywhere', 'Enforced: Gatekeeper assessment disabled') })
            if ($permissive.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Warning:** $($permissive.Count) assigned policy/policies allow apps from anywhere or disable Gatekeeper "
                $testResultMarkdown += "assessment, which permits unsigned binaries to run on devices scoped to them."
            }
        } else {
            $testResultMarkdown += "`nNo assigned policy restricts macOS app download locations. "
            $testResultMarkdown += "Set **Allow apps downloaded from these locations** to **Mac App Store and identified developers** or stricter, "
            $testResultMarkdown += "or enforce the **System Policy Control** payload, and assign the policy to your macOS groups."
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
