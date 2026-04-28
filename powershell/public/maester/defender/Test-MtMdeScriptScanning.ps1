function Test-MtMdeScriptScanning {
    <#
    .SYNOPSIS
        Checks if script scanning is enabled in Microsoft Defender Antivirus policies

    .DESCRIPTION
        Verify that script scanning is enabled to block malicious scripts.
        Disabled script scanning allows malicious PowerShell, JavaScript, and VBScript execution.
    .PARAMETER ComplianceLogic
        Determines how policy compliance is evaluated. 'AllPolicies' requires every assigned policy to be compliant; 'AnyPolicy' requires at least one. Default: 'AllPolicies'.

    .PARAMETER PolicyFiltering
        Determines which Defender Antivirus policies are evaluated. 'OnlyAssigned' (default) checks only assigned policies; 'IncludeUnassigned' includes unassigned policies; 'All' includes every policy.


    .EXAMPLE
        Test-MtMdeScriptScanning

        Returns true if all assigned Defender AV policies have script scanning enabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeScriptScanning
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [ValidateSet('AllPolicies', 'AnyPolicy')]
        [string]$ComplianceLogic = 'AllPolicies',

        [ValidateSet('All', 'IncludeUnassigned', 'OnlyAssigned')]
        [string]$PolicyFiltering = 'OnlyAssigned'
    )

    Write-Verbose "Running Test-MtMdeScriptScanning..."

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
            -SettingId "device_vendor_msft_policy_config_defender_allowscriptscanning" `
            -ComplianceCheck "Boolean" `
            -ExpectedValue "_1"

        $testResult = $compliance.IsCompliant

        if ($testResult) {
            $testResultMarkdown = "Well done. Script scanning is enabled in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
        } else {
            $testResultMarkdown = "Script scanning is not properly configured in all policies."
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
