function Test-MtAdWellKnownSecurityPrincipalsCount {
    <#
    .SYNOPSIS
    Counts the number of well-known security principal objects in Active Directory.

    .DESCRIPTION
    This test retrieves the Active Directory configuration data for the collection of
    well-known security principals and reports how many
    objects are present.

    .EXAMPLE
    Test-MtAdWellKnownSecurityPrincipalsCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdWellKnownSecurityPrincipalsCount
    #>
    [MaesterTest(
        Id = 'AD-CFG-10',
        Title = 'Well-known security principals count should be retrievable',
        Product = 'ad',
        Feature = 'directory-configuration',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Configuration/*:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdWellKnownSecurityPrincipalsCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Configuration')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState -or $null -eq $adState.Configuration -or $null -eq $adState.Configuration.WellKnownSecurityPrincipals) {
        throw 'Well-known security principal inventory could not be retrieved.'
    }

    $config = $adState.Configuration

    $wellKnownPrincipals = if ($null -ne $config) { $config.WellKnownSecurityPrincipals } else { $null }
    $wellKnownPrincipalsCount = @($wellKnownPrincipals).Count
    $hasData = $null -ne $config.WellKnownSecurityPrincipals

    # Return $true if configuration data was retrieved successfully.
    $testResult = $hasData

    # Generate markdown results
    if ($hasData) {
        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| WellKnownSecurityPrincipals Count | $wellKnownPrincipalsCount |" + "`n"
        $testResultMarkdown = "Active Directory well-known security principals have been enumerated ($wellKnownPrincipalsCount found). Review the actual identities; counts vary by forest and OS version and do not establish tampering.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration data for WellKnownSecurityPrincipals. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
