function Test-MtMdeScheduleScanDay {
    <#
    .SYNOPSIS
        Checks if a scheduled scan day is configured

    .DESCRIPTION
        Tests that all assigned Microsoft Defender Antivirus policies have the
        schedule scan day configured. An irregular scan schedule may miss
        persistent threats on managed devices.

    .EXAMPLE
        Test-MtMdeScheduleScanDay

        Returns $true if all policies have scan day configured.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeScheduleScanDay
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [ValidateSet('AllPolicies', 'AnyPolicy')]
        [string]$ComplianceLogic = 'AllPolicies',

        [ValidateSet('All', 'IncludeUnassigned', 'OnlyAssigned')]
        [string]$PolicyFiltering = 'OnlyAssigned'
    )

    Write-Verbose "Running Test-MtMdeScheduleScanDay..."

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
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
