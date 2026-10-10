function Test-MtMdeQuickScanTime {
    <#
    .SYNOPSIS
        Checks that quick scan time configuration is not required

    .DESCRIPTION
        Verifies that the quick scan time setting does not need to be configured
        in Microsoft Defender Antivirus policies. Quick scans are replaced by
        real-time protection, so this setting is not required for compliance.
    .PARAMETER ComplianceLogic
        Determines how policy compliance is evaluated. 'AllPolicies' requires every assigned policy to be compliant; 'AnyPolicy' requires at least one. Default: 'AllPolicies'.

    .PARAMETER PolicyFiltering
        Determines which Defender Antivirus policies are evaluated. 'OnlyAssigned' (default) checks only assigned policies; 'IncludeUnassigned' includes unassigned policies; 'All' includes every policy.

    .PARAMETER ComplianceLogic
        Specify compliance logic: AllPolicies or AnyPolicy

    .PARAMETER PolicyFiltering
        Specify policy filtering: All, IncludeUnassigned, or OnlyAssigned

    .EXAMPLE
        Test-MtMdeQuickScanTime

        Returns $true as this setting is not required.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeQuickScanTime
    #>
    [MaesterTest(
        Id = 'MT.1159',
        Title = 'Quick Scan Time configuration is not required.',
        Severity = 'High',
        Category = 'Maester/Defender',
        Product = 'Defender',
        Tag = ('Defender', 'Maester'),
        Service = 'Graph',
        Author = 'bdrogja'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [ValidateSet('AllPolicies', 'AnyPolicy')]
        [string]$ComplianceLogic = 'AllPolicies',

        [ValidateSet('All', 'IncludeUnassigned', 'OnlyAssigned')]
        [string]$PolicyFiltering = 'OnlyAssigned'
    )

    Write-Verbose "Running Test-MtMdeQuickScanTime..."

    $deviceCount = 0
    $policyConfig = $null
    $deviceCount = Get-MdeDeviceCount
    $policyConfig = Get-MdePolicyConfiguration -PolicyFiltering $PolicyFiltering

if ($deviceCount -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "No MDE-managed Windows devices found"
        return $null
    }

    if ($policyConfig.TotalCount -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "No assigned Microsoft Defender Antivirus policies found"
        return $null
    }

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
}
