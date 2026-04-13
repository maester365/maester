function Test-MtMdeMappedDriveScanning {
    <#
    .SYNOPSIS
        Checks if full scan on mapped network drives is disabled in Microsoft Defender Antivirus policies

    .DESCRIPTION
        Verify that full scan of mapped network drives is disabled for performance.
        Full scan on mapped drives can cause significant performance issues.

    .EXAMPLE
        Test-MtMdeMappedDriveScanning

        Returns true if all assigned Defender AV policies have full scan on mapped network drives disabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeMappedDriveScanning
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-MtMdeMappedDriveScanning..."

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
        -SettingId "device_vendor_msft_policy_config_defender_allowfullscanonmappednetworkdrives" `
        -ComplianceCheck "Boolean" `
        -ExpectedValue "_0"

    $testResult = $compliance.IsCompliant

    if ($testResult) {
        $testResultMarkdown = "Well done. Full scan on mapped network drives is correctly disabled in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
    } else {
        $testResultMarkdown = "Full scan on mapped network drives should be disabled for performance in all policies."
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
