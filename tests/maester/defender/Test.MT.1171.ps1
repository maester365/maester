function Test-MtMdeSubmitSamplesConsent {
    <#
    .SYNOPSIS
        Checks if sample submission consent is configured to send safe samples automatically

    .DESCRIPTION
        Verify that sample submission consent is configured to send safe samples
        automatically. Restricted sample submission reduces threat intelligence
        and protection quality.
    .PARAMETER ComplianceLogic
        How the evaluated policies combine into one result. 'EffectivePolicy' (default) passes when at least one policy sets a compliant value and no policy sets a non-compliant value; policies that don't configure the setting are ignored, and it does not check which devices each policy is assigned to. 'AllPolicies' requires every policy to configure the setting compliantly. 'AnyPolicy' requires at least one compliant policy. Unassigned policies included through PolicyFiltering count as if they were assigned.

    .PARAMETER PolicyFiltering
        Determines which Defender Antivirus policies are evaluated. 'OnlyAssigned' (default) checks only assigned policies; 'IncludeUnassigned' includes unassigned policies; 'All' includes every policy.

    .EXAMPLE
        Test-MtMdeSubmitSamplesConsent

        Returns $true if the assigned Defender Antivirus policies together have sample submission consent configured to send safe samples automatically, with no policy setting a non-compliant value.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeSubmitSamplesConsent
    #>
    [MaesterTest(
        Id = 'MT.1171',
        Title = 'Sample Submission should send safe samples automatically.',
        Product = 'defender',
        RelatedProduct = 'intune',
        Feature = 'endpoint-antivirus',
        Area = 'devices',
        ResourceType = 'Policy',
        Severity = 'Medium',
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

    Write-Verbose "Running Test-MtMdeSubmitSamplesConsent..."

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
        -SettingId "device_vendor_msft_policy_config_defender_submitsamplesconsent" `
        -ComplianceCheck "Enum" `
        -ValidValues @("_1", "_2")

    $testResult = $compliance.IsCompliant

    $testResultMarkdown = Get-MdeComplianceResultMarkdown -Compliance $compliance -SettingName 'Sample submission consent' -ExpectedState 'correctly configured'
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
