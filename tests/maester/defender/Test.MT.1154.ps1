function Test-MtMdeRemovableDriveScanning {
    <#
    .SYNOPSIS
        Checks if full scan of removable drives is enabled in Microsoft Defender Antivirus policies

    .DESCRIPTION
        Verify that full scan of removable drives is enabled to mitigate USB risks.
        Disabled removable drive scanning allows USB-based malware infections.
    .PARAMETER ComplianceLogic
        Determines how policy compliance is evaluated. 'AllPolicies' requires every assigned policy to be compliant; 'AnyPolicy' requires at least one. Default: 'AllPolicies'.

    .PARAMETER PolicyFiltering
        Determines which Defender Antivirus policies are evaluated. 'OnlyAssigned' (default) checks only assigned policies; 'IncludeUnassigned' includes unassigned policies; 'All' includes every policy.

    .PARAMETER ComplianceLogic
        Specify compliance logic: AllPolicies or AnyPolicy

    .PARAMETER PolicyFiltering
        Specify policy filtering: All, IncludeUnassigned, or OnlyAssigned

    .EXAMPLE
        Test-MtMdeRemovableDriveScanning

        Returns true if all assigned Defender AV policies have removable drive scanning enabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeRemovableDriveScanning
    #>
    [MaesterTest(
        Id = 'MT.1154',
        Title = 'Full Scan Removable Drives should be enabled.',
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

    Write-Verbose "Running Test-MtMdeRemovableDriveScanning..."

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
        -SettingId "device_vendor_msft_policy_config_defender_allowfullscanremovabledrivescanning" `
        -ComplianceCheck "Boolean" `
        -ExpectedValue "_1"

    $testResult = $compliance.IsCompliant

    if ($testResult) {
        $testResultMarkdown = "Well done. Full scan on removable drives is enabled in all $($policyConfig.TotalCount) assigned Defender Antivirus policies."
    } else {
        $testResultMarkdown = "Full scan on removable drives is not properly configured in all policies."
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
