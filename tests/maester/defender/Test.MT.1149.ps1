function Test-MtMdeBehaviorMonitoring {
    <#
    .SYNOPSIS
        Checks if behavior monitoring is enabled in Microsoft Defender Antivirus policies

    .DESCRIPTION
        Verify that behavior monitoring is enabled - prerequisite for EDR capabilities.
        Disabled behavior monitoring reduces ability to detect zero-day threats and advanced persistent threats.
    .PARAMETER ComplianceLogic
        How the evaluated policies combine into one result. 'EffectivePolicy' (default) passes when at least one policy sets a compliant value and no policy sets a non-compliant value; policies that don't configure the setting are ignored, and it does not check which devices each policy is assigned to. 'AllPolicies' requires every policy to configure the setting compliantly. 'AnyPolicy' requires at least one compliant policy. Unassigned policies included through PolicyFiltering count as if they were assigned.

    .PARAMETER PolicyFiltering
        Determines which Defender Antivirus policies are evaluated. 'OnlyAssigned' (default) checks only assigned policies; 'IncludeUnassigned' includes unassigned policies; 'All' includes every policy.

    .EXAMPLE
        Test-MtMdeBehaviorMonitoring

        Returns $true if the assigned Defender Antivirus policies together have behavior monitoring enabled, with no policy setting a non-compliant value.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeBehaviorMonitoring
    #>
    [MaesterTest(
        Id = 'MT.1149',
        Title = 'Behavior Monitoring should be enabled.',
        Product = 'defender',
        RelatedProduct = 'intune',
        Feature = 'endpoint-antivirus',
        Area = 'devices',
        ResourceType = 'Policy',
        Severity = 'High',
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

    Write-Verbose "Running Test-MtMdeBehaviorMonitoring..."

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
        -SettingId "device_vendor_msft_policy_config_defender_allowbehaviormonitoring" `
        -ComplianceCheck "Boolean" `
        -ExpectedValue "_1"

    $testResult = $compliance.IsCompliant

    $testResultMarkdown = Get-MdeComplianceResultMarkdown -Compliance $compliance -SettingName 'Behavior monitoring' -ExpectedState 'enabled'
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
