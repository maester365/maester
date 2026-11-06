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

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    # Get tombstone lifetime from the collected directory configuration
    $tombstoneLifetime = $adState.Configuration.TombstoneLifetime

    # Default values: 60 days for older forests, 180 days for newer forests
    $defaultValue = 180

    # The unreadable value used to be replaced with $defaultValue here. That made the condition
    # below impossible to fail and left the "Unable to retrieve" branch unreachable, so a forest
    # whose tombstone lifetime could not be read was reported as retaining deleted objects for 180
    # days and as meeting the recommendation, on a number this test supplied itself. Worse, the
    # substituted 180 is only the default for newer forests; an older forest defaults to 60, so the
    # invented value could also claim the recommendation was met when it was not.
    #
    # Without the substitution the branch the author wrote for that case is the one that runs, which
    # is what the title of this check asserts: the tombstone lifetime should be retrievable.

    # Test passes if we successfully retrieved tombstone lifetime
    $testResult = $null -ne $tombstoneLifetime

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Tombstone Lifetime | $tombstoneLifetime days |" + "`n"
        $result += "| Recommended minimum | $defaultValue days |" + "`n"
        $result += "| Forest Name | $($adState.Forest.Name) |" + "`n"

        $recommendation = if ($tombstoneLifetime -ge 180) { "✅ Meets recommendation (180+ days)" } else { "⚠️ Below recommendation (180 days)" }
        $result += "| Recommendation | $recommendation |" + "`n"

        $testResultMarkdown = "The Active Directory tombstone lifetime has been retrieved. Deleted objects are retained for $tombstoneLifetime days before permanent removal.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve tombstone lifetime. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
