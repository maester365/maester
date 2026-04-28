function Test-MtMdeSignatureUpdateInterval {
    <#
    .SYNOPSIS
        Checks if signature update interval is configured between 1-4 hours

    .DESCRIPTION
        Tests that all assigned Microsoft Defender Antivirus policies have the
        signature update interval configured within the recommended range of 1-4 hours.
        Infrequent signature updates reduce detection of the latest threats.

    .EXAMPLE
        Test-MtMdeSignatureUpdateInterval

        Returns $true if all policies have signature update interval configured between 1-4 hours.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeSignatureUpdateInterval
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-MtMdeSignatureUpdateInterval..."

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
        -SettingId "device_vendor_msft_policy_config_defender_signatureupdateinterval" `
        -ComplianceCheck "Range" `
        -RangeMin 1 `
        -RangeMax 4

    $testResult = $compliance.IsCompliant

    if ($testResult) {
        $testResultMarkdown = "Well done. Signature update interval is correctly configured between 1-4 hours in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
    } else {
        $testResultMarkdown = "Signature update interval is not properly configured in all policies."
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
