function Test-MtAdOptionalFeatureCount {
    <#
    .SYNOPSIS
    Inventories available and enabled Active Directory optional features.

    .DESCRIPTION
    Active Directory optional features provide additional functionality beyond the
    base Active Directory capabilities. Common optional features include:
    - Recycle Bin: Allows restoration of deleted objects
    - Privileged Access Management (PAM): Time-based group membership
    - Other forest or domain-specific features

    Understanding which optional features are available helps assess the
    capabilities and security posture of the Active Directory environment.

    .EXAMPLE
    Test-MtAdOptionalFeatureCount

    Returns $true if optional feature data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdOptionalFeatureCount
    #>
    [MaesterTest(
        Id = 'AD-FEAT-01',
        Title = 'Optional features and enabled scopes should be investigated',
        Product = 'ad',
        Feature = 'directory-configuration',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:msDS-OptionalFeature:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdOptionalFeatureCount"

    $adState = Get-MtADDomainState -Categories @('OptionalFeatures')

    if ($null -eq $adState -or $null -eq $adState.OptionalFeatures) {
        throw 'Optional-feature inventory could not be retrieved.'
    }

    $optionalFeatures = $adState.OptionalFeatures
    $featureCount = @($optionalFeatures).Count
    foreach ($feature in $optionalFeatures) {
        if ($feature.PSObject.Properties.Name -notcontains 'IsEnabled' -or $null -eq $feature.IsEnabled) {
            throw "Enabled status could not be retrieved for optional feature '$($feature.Name)'."
        }
    }
    $enabledFeatures = @($optionalFeatures | Where-Object { $_.IsEnabled -eq $true })
    $result = "| Metric | Value |`n| --- | --- |`n"
    $result += "| Available optional features | $featureCount |`n"
    $result += "| Enabled optional features | $($enabledFeatures.Count) |`n`n"
    $result += "| Feature | Enabled | Enabled scopes |`n| --- | --- | --- |`n"
    foreach ($feature in $optionalFeatures) {
        $scopeText = 'None'
        if ($feature.PSObject.Properties.Name -notcontains 'EnabledScopes') {
            throw "Enabled scopes were not collected for optional feature '$($feature.Name)'."
        }
        if ($null -eq $feature.EnabledScopes) {
            throw "Enabled scopes could not be retrieved for optional feature '$($feature.Name)'."
        }
        if (@($feature.EnabledScopes).Count -gt 0) {
            $scopeText = (@($feature.EnabledScopes) | ForEach-Object { ([string]$_).Replace('|', '&#124;') }) -join '<br>'
        }
        $name = ([string]$feature.Name).Replace('|', '&#124;')
        $result += "| $name | $($feature.IsEnabled) | $scopeText |`n"
    }
    Add-MtTestResultDetail -Result "Optional features and their enabled scopes are listed for review. Coverage crosswalk: former AD-CFG-04 and AD-FEAT-02 are included here under the single directory-configuration Feature. AD-FOR-04 separately checks whether Recycle Bin is enabled and links this inventory.`n`n$result" -Investigate
    return $true
}
