function Test-MtMdeCloudExtendedTimeout {
    <#
    .SYNOPSIS
        Checks if cloud extended timeout is configured between 30-50 seconds

    .DESCRIPTION
        Tests that the assigned Microsoft Defender Antivirus policies have the
        cloud extended timeout configured within the recommended range of 30-50 seconds.
        Insufficient cloud timeout may prevent thorough analysis of suspicious files.
    .PARAMETER ComplianceLogic
        How the evaluated policies combine into one result. 'EffectivePolicy' (default) passes when at least one policy sets a compliant value and no policy sets a different value; policies that don't configure the setting are ignored, and it does not check which devices each policy is assigned to. 'AllPolicies' requires every policy to configure the setting compliantly. 'AnyPolicy' requires at least one compliant policy. Unassigned policies included through PolicyFiltering count as if they were assigned.

    .PARAMETER PolicyFiltering
        Determines which Defender Antivirus policies are evaluated. 'OnlyAssigned' (default) checks only assigned policies; 'IncludeUnassigned' includes unassigned policies; 'All' includes every policy.

    .EXAMPLE
        Test-MtMdeCloudExtendedTimeout

        Returns $true if the assigned Defender Antivirus policies together have cloud extended timeout configured between 30-50 seconds, with no policy setting a different value.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeCloudExtendedTimeout
    #>
    [MaesterTest(
        Id = 'MT.1162',
        Title = 'Cloud Extended Timeout should be 30-50 seconds.',
        Product = 'defender',
        RelatedProduct = 'intune',
        Feature = 'endpoint-antivirus',
        Area = 'devices',
        ResourceType = 'Policy',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1204.002',
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

    Write-Verbose "Running Test-MtMdeCloudExtendedTimeout..."

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
        -SettingId "device_vendor_msft_policy_config_defender_cloudextendedtimeout" `
        -ComplianceCheck "Range" `
        -RangeMin 30 `
        -RangeMax 50

    $testResult = $compliance.IsCompliant

    $testResultMarkdown = Get-MdeComplianceResultMarkdown -Compliance $compliance -SettingName 'Cloud extended timeout' -ExpectedState 'correctly configured between 30-50 seconds'
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
