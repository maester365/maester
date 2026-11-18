function Test-MtAdRecycleBinStatus {
    <#
    .SYNOPSIS
    Retrieves the Active Directory Recycle Bin status.

    .DESCRIPTION
    This test checks whether the Active Directory Recycle Bin is enabled in the forest.
    The Recycle Bin provides enhanced protection against accidental deletion by allowing
    recovery of deleted objects without restoring from backup.

    .EXAMPLE
    Test-MtAdRecycleBinStatus

    Returns $true if Recycle Bin data is accessible.
    The test result includes whether the Recycle Bin is enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdRecycleBinStatus
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-FOR-04',
        Title = 'Active Directory Recycle Bin should be enabled',
        Product = 'ad',
        Feature = 'directory-configuration',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:crossRef:ReadProperty', 'ActiveDirectory:Ldap:msDS-OptionalFeature:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdRecycleBinStatus"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Forest', 'OptionalFeatures')

    if ($null -eq $adState -or $null -eq $adState.OptionalFeatures) {
        throw 'Unable to retrieve optional features; Recycle Bin status cannot be determined.'
    }

    $recycleBinFeature = @($adState.OptionalFeatures | Where-Object { $_.Name -eq 'Recycle Bin Feature' })
    if ($recycleBinFeature.Count -ne 1) {
        throw 'Unable to identify exactly one Recycle Bin Feature in the optional-feature inventory. Verify directory access and the forest configuration.'
    }
    if ($null -eq $recycleBinFeature[0].IsEnabled) {
        throw 'Recycle Bin enabled status could not be retrieved.'
    }

    $isEnabled = $recycleBinFeature[0].IsEnabled -eq $true
    $forestName = $adState.Forest.Name
    $scopes = @($recycleBinFeature[0].EnabledScopes) -join ', '
    $scopeText = if ($scopes) { [System.Net.WebUtility]::HtmlEncode($scopes).Replace('|', '&#124;') } else { 'None recorded' }
    $result = "| Property | Value |`n| --- | --- |`n"
    $result += "| Forest | $([System.Net.WebUtility]::HtmlEncode([string]$forestName).Replace('|', '&#124;')) |`n"
    $result += "| Forest functional level | $($adState.Forest.ForestMode) |`n"
    $result += "| Recycle Bin enabled | $isEnabled |`n"
    $result += "| Enabled scopes | $scopeText |`n"
    $result += "| Status | $(if ($isEnabled) { 'Enabled' } else { 'Not enabled' }) |`n"
    $context = 'Recycle Bin preserves deleted-object attributes for recovery without an authoritative restore. Enablement is irreversible and can increase directory database size; review retention and recovery requirements. The feature flag does not prove backup or recovery readiness.'
    if ($isEnabled) {
        Add-MtTestResultDetail -Result "Well done. Active Directory Recycle Bin is enabled in forest $forestName. $context Coverage crosswalk: former AD-CFG-05 is included here; AD-FEAT-01 provides optional-feature inventory.`n`n$result"
        return $true
    }

    Add-MtTestResultDetail -Result "Active Directory Recycle Bin is not enabled in forest $forestName. Plan and enable the Recycle Bin after checking functional-level prerequisites. $context Coverage crosswalk: former AD-CFG-05 is included here; AD-FEAT-01 provides the linked optional-feature inventory.`n`n$result"
    return $false
}
