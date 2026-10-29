function Test-MtMdeQuickScanTime {
    <#
    .SYNOPSIS
        Checks that quick scan time configuration is not required

    .DESCRIPTION
        Verifies that the quick scan time setting does not need to be configured
        in Microsoft Defender Antivirus policies. Quick scans are replaced by
        real-time protection, so this setting is not required for compliance.
    .PARAMETER ComplianceLogic
        How the evaluated policies combine into one result: 'EffectivePolicy' (default), 'AllPolicies' or 'AnyPolicy'. This setting is optional, so a policy that doesn't set it counts as compliant and the check passes under every logic, including when no policy sets it.

    .PARAMETER PolicyFiltering
        Determines which Defender Antivirus policies are evaluated. 'OnlyAssigned' (default) checks only assigned policies; 'IncludeUnassigned' includes unassigned policies; 'All' includes every policy.

    .EXAMPLE
        Test-MtMdeQuickScanTime

        Returns $true as this setting is not required.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeQuickScanTime
    #>
    [MaesterTest(
        Id = 'MT.1159',
        Title = 'Quick Scan Time configuration is not required.',
        Product = 'defender',
        RelatedProduct = 'intune',
        Feature = 'endpoint-antivirus',
        Area = 'devices',
        ResourceType = 'Policy',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'Graph',
        Author = 'bdrogja',
        Contributor = 'Gbenrotto'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [ValidateSet('EffectivePolicy', 'AllPolicies', 'AnyPolicy')]
        [string]$ComplianceLogic = 'EffectivePolicy',

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

    $testResultMarkdown = Get-MdeComplianceResultMarkdown -Compliance $compliance -SettingName 'Quick scan time configuration' -ExpectedState 'not required'
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
