function Get-MtDefenderDeviceSecurityRecommendationInstance {
    <#
    .SYNOPSIS
    Returns one MT.1269 instance per Defender Vulnerability Management security configuration.

    .DESCRIPTION
    Instance source of the MT.1269 family. The suffix is the configuration ID
    (MT.1269.<configurationId>) and the title names the configuration, so each Defender recommendation
    becomes its own row with its own result, the way MT.1024 does for Entra recommendations.

    When Defender returns no assessment at all the source emits nothing and the engine skips the family
    with NoInstances. That is deliberate: a tenant with no onboarded device has no configuration to be
    compliant with, and must never be reported as having none non-compliant.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $configurations = Get-MtDefenderSecureConfigurationAssessment

    foreach ($configuration in $configurations) {
        # A configuration that applies to no device has no outcome to judge.
        if ($configuration.ApplicableDeviceCount -le 0) { continue }

        $name = if ([string]::IsNullOrWhiteSpace($configuration.Name)) {
            $configuration.ConfigurationId
        } else {
            $configuration.Name
        }

        # Severity follows the source, as #2510 asks: Defender's own rated impact on the configuration
        # score, 1 to 10. It goes on the instance because that is where the engine reads a family's
        # per-instance severity (Invoke-MtNativePlan resolves config, then the instance, then the
        # attribute); -Severity on Add-MtTestResultDetail is never reached once the attribute declares
        # one.
        # Left unset when the knowledge base has no impact for this configuration. The engine's
        # precedence is config, then instance, then attribute (Invoke-MtNativePlan.ps1:467-470) and
        # it tests the instance value for truthiness, so $null falls through to the attribute's
        # Medium. Deriving it from a missing impact would report a failing configuration as Low.
        $severity = if ($null -eq $configuration.Impact) { $null }
        elseif ($configuration.Impact -ge 8) { 'High' }
        elseif ($configuration.Impact -ge 4) { 'Medium' }
        else { 'Low' }

        [pscustomobject]@{
            Id       = $configuration.ConfigurationId
            Title    = "Every device should comply with the Defender recommendation '$name'."
            Severity = $severity
            Data     = $configuration
        }
    }
}

function Test-MtDefenderDeviceSecurityRecommendation {
    <#
    .SYNOPSIS
    Ensure no device is left non-compliant with a Defender Vulnerability Management security
    recommendation.

    .DESCRIPTION
    Defender Vulnerability Management assesses each onboarded device against a catalogue of security
    configurations and reports, per configuration, which devices comply. An assessor normally reads that
    in the Defender portal. This check brings it into a Maester run.

    It runs once per assessed security configuration, following the InstanceSource pattern MT.1024
    introduced. A configuration passes when every device it applies to is compliant with it, and fails
    when any applicable device is not. The result names the count and up to ten of the devices, with the
    configuration's risk description and its rated impact on the configuration score.

    Only configurations Defender reports as applicable to at least one device are assessed. A tenant
    with no Defender Vulnerability Management data is skipped, not passed.

    .OUTPUTS
    [bool] - True when every applicable device complies with the configuration, false when any does not,
    null when the family is skipped.

    .EXAMPLE
    Test-MtDefenderDeviceSecurityRecommendation

    Returns one result per assessed Defender security configuration.

    .LINK
    https://maester.dev/docs/commands/Test-MtDefenderDeviceSecurityRecommendation
    #>
    [MaesterTest(
        Id = 'MT.1269',
        Title = 'Devices should comply with the Defender Vulnerability Management security recommendations.',
        Product = 'defender',
        Feature = 'exposure-management',
        Area = 'devices',
        ResourceType = 'Device',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Lifecycle = 'Preview',
        Service = 'Graph',
        License = 'DEFENDER_XDR',
        InstanceSource = 'Get-MtDefenderDeviceSecurityRecommendationInstance',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The security configuration to check, supplied by the engine.
        $Instance
    )

    $configuration = $Instance.Data
    $nonCompliant = [int]$configuration.NonCompliantDeviceCount
    $applicable = [int]$configuration.ApplicableDeviceCount
    $testResult = $nonCompliant -eq 0

    $testResultMarkdown = "Defender assesses this configuration on **$applicable** device(s). "
    if ($testResult) {
        $testResultMarkdown += "All of them comply.`n`n"
    } else {
        $testResultMarkdown += "**$nonCompliant** of them do not comply.`n`n"
    }

    $testResultMarkdown += "| Property | Value |`n| --- | --- |`n"
    $testResultMarkdown += "| Configuration ID | ``$($configuration.ConfigurationId)`` |`n"
    $testResultMarkdown += "| Category | $($configuration.Category) |`n"
    $testResultMarkdown += "| Subcategory | $($configuration.Subcategory) |`n"
    $impactoTexto = if ($null -eq $configuration.Impact) { 'not published by the knowledge base' } else { "$($configuration.Impact) of 10" }
    $testResultMarkdown += "| Impact on configuration score | $impactoTexto |`n"
    $testResultMarkdown += "| Applicable devices | $applicable |`n"
    $testResultMarkdown += "| Non-compliant devices | $nonCompliant |`n"

    if (-not [string]::IsNullOrWhiteSpace($configuration.Description)) {
        $testResultMarkdown += "`n$($configuration.Description)`n"
    }

    if (-not $testResult) {
        if (-not [string]::IsNullOrWhiteSpace($configuration.RiskDescription)) {
            $testResultMarkdown += "`n**Risk.** $($configuration.RiskDescription)`n"
        }
        $devices = @($configuration.NonCompliantDeviceList | Where-Object { $_ })
        if ($devices.Count -gt 0) {
            $testResultMarkdown += "`nNon-compliant devices (up to ten shown): $($devices -join ', ')`n"
        }
        $testResultMarkdown += "`nRemediate the configuration on the devices listed, or accept the risk in the Defender portal so it stops being reported."
    } else {
        $testResultMarkdown += "`nWell done. Every device this configuration applies to complies with it."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
