function Test-MtMdeQuickScanTime {
    <#
    .SYNOPSIS
        Checks that quick scan time configuration is not required

    .DESCRIPTION
        Verifies that the quick scan time setting does not need to be configured
        in Microsoft Defender Antivirus policies. Quick scans are replaced by
        real-time protection, so this setting is not required for compliance.

    .EXAMPLE
        Test-MtMdeQuickScanTime

        Returns $true as this setting is not required.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeQuickScanTime
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [ValidateSet('AllPolicies', 'AnyPolicy')]
        [string]$ComplianceLogic = 'AllPolicies',

        [ValidateSet('All', 'IncludeUnassigned', 'OnlyAssigned')]
        [string]$PolicyFiltering = 'OnlyAssigned'
    )

    Write-Verbose "Running Test-MtMdeQuickScanTime..."

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $deviceCount = 0
    $policyConfig = $null
    try {
        $deviceCount = Get-MdeDeviceCount
        $policyConfig = Get-MdePolicyConfiguration -PolicyFiltering $PolicyFiltering
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ($deviceCount -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "No MDE-managed Windows devices found"
        return $null
    }

    if ($policyConfig.TotalCount -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "No assigned Microsoft Defender Antivirus policies found"
        return $null
    }

    try {
    $compliance = Test-MdePolicyCompliance -PolicyConfiguration $policyConfig `
        -ComplianceLogic $ComplianceLogic `
        -SettingId "device_vendor_msft_policy_config_defender_schedulequickscantime" `
        -ComplianceCheck "NotRequired"

    $testResult = $compliance.IsCompliant

    if ($testResult) {
        $testResultMarkdown = "Well done. Quick scan time configuration is not required and all $($policyConfig.TotalCount) assigned Defender Antivirus policies are compliant."
    } else {
        $testResultMarkdown = "Quick scan time configuration is not properly configured in all policies."
        if ($compliance.NonCompliantPolicies.Count -gt 0) {
            $testResultMarkdown += "`n`nNon-compliant policies: $($compliance.NonCompliantPolicies -join ', ')"
        }
        if ($compliance.NotConfiguredPolicies.Count -gt 0) {
            $testResultMarkdown += "`n`nPolicies without this setting configured: $($compliance.NotConfiguredPolicies -join ', ')"
        }
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
