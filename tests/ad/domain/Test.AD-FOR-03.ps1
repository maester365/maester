function Test-MtAdTombstoneLifetime {
    <#
    .SYNOPSIS
    Retrieves the tombstone lifetime in days.

    .DESCRIPTION
    This test retrieves the tombstone lifetime setting from Active Directory.
    The tombstone lifetime determines how long deleted objects are retained
    before being permanently removed. This is critical for accidental deletion
    recovery and replication stability.

    .EXAMPLE
    Test-MtAdTombstoneLifetime

    Returns $true if tombstone lifetime data is accessible.
    The test result includes the current tombstone lifetime value.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTombstoneLifetime
    #>
    [MaesterTest(
        Id = 'AD-FOR-03',
        Title = 'Tombstone lifetime should be retrievable',
        Product = 'ad',
        Feature = 'directory-configuration',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Configuration/*:ReadProperty', 'ActiveDirectory:Ldap:crossRef:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdTombstoneLifetime"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Configuration', 'Forest')

    if ($null -eq $adState -or $null -eq $adState.Configuration) {
        throw 'Unable to retrieve the Directory Service configuration; tombstone lifetime cannot be determined.'
    }
    if ($adState.Configuration.PSObject.Properties.Name -contains 'DirectoryServiceRetrieved' -and
        $adState.Configuration.DirectoryServiceRetrieved -ne $true) {
        throw 'Directory Service object could not be retrieved; an absent tombstone lifetime cannot be inferred.'
    }

    $configured = $adState.Configuration.TombstoneLifetime
    $usingDefault = $null -eq $configured -or [string]::IsNullOrWhiteSpace([string]$configured)
    # An absent tombstoneLifetime attribute means 60 days, including in upgraded forests.
    $effective = if ($usingDefault) { 60 } else { [int]$configured }
    $configuredText = if ($usingDefault) { 'Not set' } else { "$configured days" }
    $result = "| Property | Value |`n| --- | --- |`n"
    $result += "| Configured tombstoneLifetime | $configuredText |`n"
    $result += "| Effective tombstone lifetime | $effective days |`n"
    $result += "| Using the unset-attribute default (60 days) | $usingDefault |`n"
    $result += "| Forest name | $($adState.Forest.Name) |`n"
    Add-MtTestResultDetail -Result "Well done. Tombstone lifetime was determined from the Directory Service configuration.`n`n$result"
    return $true
}
