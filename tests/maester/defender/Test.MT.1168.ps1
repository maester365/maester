function Test-MtMdeRetainCleanedMalware {
    <#
    .SYNOPSIS
        Checks if cleaned malware is retained for at least 30 days for forensic analysis

    .DESCRIPTION
        Verify that cleaned malware is retained for at least 30 days to support forensic
        analysis and threat investigation. Short retention may impact forensic analysis
        and threat investigation.
    .PARAMETER ComplianceLogic
        How the evaluated policies combine into one result. 'EffectivePolicy' (default) passes when at least one policy sets a compliant value and no policy sets a non-compliant value; policies that don't configure the setting are ignored, and it does not check which devices each policy is assigned to. 'AllPolicies' requires every policy to configure the setting compliantly. 'AnyPolicy' requires at least one compliant policy. Unassigned policies included through PolicyFiltering count as if they were assigned.

    .PARAMETER PolicyFiltering
        Determines which Defender Antivirus policies are evaluated. 'OnlyAssigned' (default) checks only assigned policies; 'IncludeUnassigned' includes unassigned policies; 'All' includes every policy.

    .EXAMPLE
        Test-MtMdeRetainCleanedMalware

        Returns $true if the assigned Defender Antivirus policies together have cleaned malware retention set to at least 30 days, with no policy setting a non-compliant value.

    .LINK
        https://maester.dev/docs/commands/Test-MtMdeRetainCleanedMalware
    #>
    [MaesterTest(
        Id = 'MT.1168',
        Title = 'Cleaned Malware should be retained for at least 30 days.',
        Product = 'defender',
        RelatedProduct = 'intune',
        Feature = 'endpoint-antivirus',
        Area = 'devices',
        ResourceType = 'Policy',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
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

    Write-Verbose "Running Test-MtMdeRetainCleanedMalware..."

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
        -SettingId "device_vendor_msft_policy_config_defender_daystoretaincleanedmalware" `
        -ComplianceCheck "MinimumValue" `
        -MinimumValue 30

    $testResult = $compliance.IsCompliant

    $testResultMarkdown = Get-MdeComplianceResultMarkdown -Compliance $compliance -SettingName 'Cleaned malware retention' -ExpectedState 'correctly configured'
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
