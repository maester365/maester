function Test-MtMdeSignatureUpdateInterval {
    <#
    .SYNOPSIS
        Checks if signature update interval is configured between 1-4 hours

    .DESCRIPTION
        Tests that the assigned Microsoft Defender Antivirus policies have the
        signature update interval configured within the recommended range of 1-4 hours.
        Infrequent signature updates reduce detection of the latest threats.
    .PARAMETER ComplianceLogic
        How the evaluated policies combine into one result. 'EffectivePolicy' (default) passes when at least one policy sets a compliant value and no policy sets a different value; policies that don't configure the setting are ignored, and it does not check which devices each policy is assigned to. 'AllPolicies' requires every policy to configure the setting compliantly. 'AnyPolicy' requires at least one compliant policy. Unassigned policies included through PolicyFiltering count as if they were assigned.

    .PARAMETER PolicyFiltering
        Determines which Defender Antivirus policies are evaluated. 'OnlyAssigned' (default) checks only assigned policies; 'IncludeUnassigned' includes unassigned policies; 'All' includes every policy.

    .EXAMPLE
        Test-MtMdeSignatureUpdateInterval

        Returns $true if the assigned Defender Antivirus policies together have signature update interval configured between 1-4 hours, with no policy setting a different value.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeSignatureUpdateInterval
    #>
    [MaesterTest(
        Id = 'MT.1163',
        Title = 'Signature Update Interval should be 1-4 hours.',
        Product = 'defender',
        RelatedProduct = 'intune',
        Feature = 'endpoint-antivirus',
        Area = 'devices',
        ResourceType = 'Policy',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1204.002',
        Control = 'nist-800-53-r5:SI-3',
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

    Write-Verbose "Running Test-MtMdeSignatureUpdateInterval..."

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
        -SettingId "device_vendor_msft_policy_config_defender_signatureupdateinterval" `
        -ComplianceCheck "Range" `
        -RangeMin 1 `
        -RangeMax 4

    $testResult = $compliance.IsCompliant

    $testResultMarkdown = Get-MdeComplianceResultMarkdown -Compliance $compliance -SettingName 'Signature update interval' -ExpectedState 'correctly configured between 1-4 hours'
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
