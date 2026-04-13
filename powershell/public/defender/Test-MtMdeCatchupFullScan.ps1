function Test-MtMdeCatchupFullScan {
    <#
    .SYNOPSIS
        Checks if catch-up full scan is disabled to avoid additional system load

    .DESCRIPTION
        Verify that catch-up full scan is disabled to avoid additional system load.
        Enabled catchup scans may cause performance issues on mobile devices.

    .EXAMPLE
        Test-MtMdeCatchupFullScan

        Returns true if all assigned Defender AV policies have catch-up full scan disabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeCatchupFullScan
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-MtMdeCatchupFullScan..."

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $deviceCount = Get-MtMdeDeviceCount
    if ($deviceCount -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "No MDE-managed Windows devices found"
        return $null
    }

    $policyConfig = Get-MdePolicyConfiguration
    if ($policyConfig.TotalCount -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "No assigned Microsoft Defender Antivirus policies found"
        return $null
    }

    $compliance = Test-MdePolicyCompliance -PolicyConfiguration $policyConfig `
        -SettingId "device_vendor_msft_policy_config_defender_disablecatchupfullscan" `
        -ComplianceCheck "Boolean" `
        -ExpectedValue "_1"

    $testResult = $compliance.IsCompliant

    if ($testResult) {
        $testResultMarkdown = "Well done. Catch-up full scan is correctly configured in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
    } else {
        $testResultMarkdown = "Catch-up full scan is not properly configured in all policies."
        if ($compliance.NonCompliantPolicies.Count -gt 0) {
            $testResultMarkdown += "`n`nNon-compliant policies: $($compliance.NonCompliantPolicies -join ', ')"
        }
        if ($compliance.NotConfiguredPolicies.Count -gt 0) {
            $testResultMarkdown += "`n`nPolicies without this setting configured: $($compliance.NotConfiguredPolicies -join ', ')"
        }
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
