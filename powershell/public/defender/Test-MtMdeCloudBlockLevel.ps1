function Test-MtMdeCloudBlockLevel {
    <#
    .SYNOPSIS
        Checks if cloud block level is set to High or higher

    .DESCRIPTION
        Tests that all assigned Microsoft Defender Antivirus policies have the
        cloud block level set to at least High. A low cloud block level reduces
        proactive threat blocking capabilities.

    .EXAMPLE
        Test-MtMdeCloudBlockLevel

        Returns $true if all policies have cloud block level set to High or higher.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeCloudBlockLevel
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-MtMdeCloudBlockLevel..."

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
        -SettingId "device_vendor_msft_policy_config_defender_cloudblocklevel" `
        -ComplianceCheck "MinimumLevel" `
        -ValidLevels @{ "_0" = 0; "_2" = 2; "_4" = 4; "_6" = 6 } `
        -MinimumValue 2

    $testResult = $compliance.IsCompliant

    if ($testResult) {
        $testResultMarkdown = "Well done. Cloud block level is correctly configured to High or higher in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
    } else {
        $testResultMarkdown = "Cloud block level is not properly configured in all policies."
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
