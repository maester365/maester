function Test-MtMdeCpuLoadFactor {
    <#
    .SYNOPSIS
        Checks if the average CPU load factor is configured between 20-30%

    .DESCRIPTION
        Tests that all assigned Microsoft Defender Antivirus policies have the
        average CPU load factor configured within the recommended range of 20-30%.
        Inappropriate CPU load settings may impact system performance or scan effectiveness.

    .EXAMPLE
        Test-MtMdeCpuLoadFactor

        Returns $true if all policies have CPU load factor configured between 20-30%.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeCpuLoadFactor
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [ValidateSet('AllPolicies', 'AnyPolicy')]
        [string]$ComplianceLogic = 'AllPolicies',

        [ValidateSet('All', 'IncludeUnassigned', 'OnlyAssigned')]
        [string]$PolicyFiltering = 'OnlyAssigned'
    )

    Write-Verbose "Running Test-MtMdeCpuLoadFactor..."

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
            -SettingId "device_vendor_msft_policy_config_defender_avgcpuloadfactor" `
            -ComplianceCheck "Range" `
            -RangeMin 20 `
            -RangeMax 30

        $testResult = $compliance.IsCompliant

        if ($testResult) {
            $testResultMarkdown = "Well done. Average CPU load factor is correctly configured between 20-30% in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
        } else {
            $testResultMarkdown = "Average CPU load factor is not properly configured in all policies."
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
