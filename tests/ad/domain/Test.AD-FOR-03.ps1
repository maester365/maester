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

    # A $null lifetime has two causes and LDAP does not let us tell them apart. @merill asked
    # for the "not set" case to report the 60 days Active Directory then uses, and that is
    # worth saying. But @coderabbitai is right that seeing the Directory Service object is not
    # proof the attribute was readable: an account without read access to tombstoneLifetime
    # gets the object back with the attribute omitted, which is byte-for-byte what "not set"
    # looks like. Passing on a value inferred from that would be the same false pass this
    # check exists to remove, so the reading is reported and the check still does not pass.
    $directoryServiceRead = [bool]$adState.Configuration.DirectoryServiceRead
    $notSetLifetime = 60
    $isAbsent = $directoryServiceRead -and $null -eq $tombstoneLifetime

    # Passes only when the forest actually returned a lifetime.
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
        $testResultMarkdown = if ($isAbsent) {
            "The Directory Service object was read, but it carries no ``tombstoneLifetime``. That is either because the forest never set one - in which case Active Directory uses $notSetLifetime days, below the 180-day recommendation - or because this account cannot read the attribute. Active Directory returns the object with the attribute omitted in both cases, so the two cannot be told apart from here, and this check does not report a lifetime it did not read. Grant read access to ``tombstoneLifetime`` on CN=Directory Service,CN=Windows NT,CN=Services to settle which it is."
        } else {
            "Unable to retrieve tombstone lifetime. Ensure you have appropriate permissions and the Active Directory module is installed."
        }
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
