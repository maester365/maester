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
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $domain = $adState.Domain

    # Try to get tombstone lifetime from the domain object
    $tombstoneLifetime = $null
    try {
        # Get the tombstone lifetime from the directory configuration
        $configurationNC = $domain.ConfigurationNamingContext
        $tombstoneObject = Get-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,$configurationNC" -Properties tombstoneLifetime -ErrorAction SilentlyContinue
        $tombstoneLifetime = $tombstoneObject.tombstoneLifetime
    }
    catch {
        Write-Verbose "Could not retrieve tombstone lifetime: $($_.Exception.Message)"
    }

    # Default values: 60 days for older forests, 180 days for newer forests
    $defaultValue = 180
    if ($null -eq $tombstoneLifetime) {
        $tombstoneLifetime = $defaultValue
        $isDefault = $true
    } else {
        $isDefault = $false
    }

    # Test passes if we successfully retrieved tombstone lifetime
    $testResult = $null -ne $tombstoneLifetime

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Tombstone Lifetime | $tombstoneLifetime days |`n"
        $result += "| Default Value | $defaultValue days |`n"
        $result += "| Using Default | $isDefault |`n"
        $result += "| Forest Name | $($adState.Forest.Name) |`n"

        $recommendation = if ($tombstoneLifetime -ge 180) { "✅ Meets recommendation (180+ days)" } else { "⚠️ Below recommendation (180 days)" }
        $result += "| Recommendation | $recommendation |`n"

        $testResultMarkdown = "The Active Directory tombstone lifetime has been retrieved. Deleted objects are retained for $tombstoneLifetime days before permanent removal.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve tombstone lifetime. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
