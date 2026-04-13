function Test-MtMdeDisableLocalAdminMerge {
    <#
    .SYNOPSIS
        Checks if local admin merge is disabled to block local exclusions

    .DESCRIPTION
        Tests that all assigned Microsoft Defender Antivirus policies have the
        disable local admin merge setting enabled. Local admin policy override
        allows privilege escalation to bypass security controls on managed devices.

    .EXAMPLE
        Test-MtMdeDisableLocalAdminMerge

        Returns $true if all policies have local admin merge disabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeDisableLocalAdminMerge
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-MtMdeDisableLocalAdminMerge..."

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
        -SettingId "device_vendor_msft_defender_configuration_disablelocaladminmerge" `
        -ComplianceCheck "Boolean" `
        -ExpectedValue "_1"

    $testResult = $compliance.IsCompliant

    if ($testResult) {
        $testResultMarkdown = "Well done. Disable local admin merge is correctly configured in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
    } else {
        $testResultMarkdown = "Disable local admin merge is not properly configured in all policies."
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
