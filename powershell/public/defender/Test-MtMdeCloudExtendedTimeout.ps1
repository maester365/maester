function Test-MtMdeCloudExtendedTimeout {
    <#
    .SYNOPSIS
        Checks if cloud extended timeout is configured between 30-50 seconds

    .DESCRIPTION
        Tests that all assigned Microsoft Defender Antivirus policies have the
        cloud extended timeout configured within the recommended range of 30-50 seconds.
        Insufficient cloud timeout may prevent thorough analysis of suspicious files.

    .EXAMPLE
        Test-MtMdeCloudExtendedTimeout

        Returns $true if all policies have cloud extended timeout configured between 30-50 seconds.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeCloudExtendedTimeout
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-MtMdeCloudExtendedTimeout..."

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
        -SettingId "device_vendor_msft_policy_config_defender_cloudextendedtimeout" `
        -ComplianceCheck "Range" `
        -RangeMin 30 `
        -RangeMax 50

    $testResult = $compliance.IsCompliant

    if ($testResult) {
        $testResultMarkdown = "Well done. Cloud extended timeout is correctly configured between 30-50 seconds in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
    } else {
        $testResultMarkdown = "Cloud extended timeout is not properly configured in all policies."
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
