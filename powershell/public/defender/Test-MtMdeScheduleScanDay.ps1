function Test-MtMdeScheduleScanDay {
    <#
    .SYNOPSIS
        Checks if scans are scheduled for every day

    .DESCRIPTION
        Tests that all assigned Microsoft Defender Antivirus policies have the
        schedule scan day properly configured for daily scanning. An irregular scan
        schedule may miss persistent threats on managed devices.

    .EXAMPLE
        Test-MtMdeScheduleScanDay

        Returns $true if all policies have scan day configured for daily scanning.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeScheduleScanDay
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-MtMdeScheduleScanDay..."

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
        -SettingId "device_vendor_msft_policy_config_defender_schedulescanday" `
        -ComplianceCheck "Enum" `
        -ValidValues @("_0", "_1", "_2", "_3", "_4", "_5", "_6", "_7")

    $testResult = $compliance.IsCompliant

    if ($testResult) {
        $testResultMarkdown = "Well done. Schedule scan day is correctly configured in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
    } else {
        $testResultMarkdown = "Schedule scan day is not properly configured in all policies."
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
