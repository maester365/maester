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
    Invoke-MtTest -Id AD-FOR-03

    Reports configured/effective lifetime and advisory status for investigation.

    .LINK
    https://maester.dev/docs/tests/AD-FOR-03
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
    param(
        # Organization-selected advisory minimum; this does not create a pass/fail threshold.
        [ValidateRange(1, 3650)]
        [int] $RecommendedMinimumDays = 180
    )

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
    if ($effective -le 0) { throw 'The effective tombstone lifetime must be a positive number of days.' }
    $configuredText = if ($usingDefault) { 'Not set' } else { "$configured days" }
    $result = "| Property | Value |`n| --- | --- |`n"
    $result += "| Configured tombstoneLifetime | $configuredText |`n"
    $result += "| Effective tombstone lifetime | $effective days |`n"
    $result += "| Using the unset-attribute default (60 days) | $usingDefault |`n"
    $result += "| Forest name | $($adState.Forest.Name) |`n"
    $result += "| Advisory minimum | $RecommendedMinimumDays days |`n"
    $result += "| Advisory status | $(if ($effective -ge $RecommendedMinimumDays) { '✅ Meets advisory' } else { '⚠️ Below advisory' }) |`n"
    Add-MtTestResultDetail -Result "ℹ️ Review tombstone retention against replication outage, backup age and recovery requirements. The advisory minimum is organization-selected, not a universal Microsoft requirement, and does not change this inventory into a pass/fail baseline. An unset attribute still has the effective 60-day default. Deleted-object recoverability with Recycle Bin also depends on deleted-object lifetime. Coverage crosswalk: former AD-CFG-01 is included here, with forest context linked through AD-FOR-01 and AD-FOR-04.`n`n$result" -Investigate
    return $true
}
