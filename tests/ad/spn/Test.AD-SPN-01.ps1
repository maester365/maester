function Test-MtAdComputerSpnServiceClassCount {
    <#
    .SYNOPSIS
    Counts the distinct SPN service classes in use by computer accounts.

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on computer objects
    and counts the distinct service classes in use. SPNs are used by Kerberos for
    authentication to services and follow the format 'serviceclass/host:port'.

    .EXAMPLE
    Test-MtAdComputerSpnServiceClassCount

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes the count of distinct service classes.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerSpnServiceClassCount
    #>
    [MaesterTest(
        Id = 'AD-SPN-01',
        Title = 'Computer SPN service class count should be retrievable',
        Product = 'ad',
        Feature = 'service-principal-names',
        Area = 'infrastructure',
        ResourceType = 'Computer',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerSpnServiceClassCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Computers')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Error -Result 'Active Directory inventory is unavailable; the declared service gate is handled by the engine.'
        return $null
    }

    $computers = $adState.Computers
    if ($null -eq $computers) { throw 'Computer collection is unavailable.' }

    # Extract all SPNs from computer objects
    $allSpns = $computers | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object { $_.servicePrincipalName } | ForEach-Object { $_ }

    # Parse SPNs to extract service classes
    $serviceClasses = $allSpns | ForEach-Object {
        if ($_ -match "^([^/]+)") {
            $matches[1]
        }
    } | Select-Object -Unique | Sort-Object

    $serviceClassCount = ($serviceClasses | Measure-Object).Count
    $totalSpnCount = ($allSpns | Measure-Object).Count

    # Test passes if we successfully retrieved SPN data
    $testResult = $null -ne $computers

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total SPNs | $totalSpnCount |" + "`n"
        $result += "| Distinct Service Classes | $serviceClassCount |" + "`n"
        $result += "`n| Service Class | SPN Count |" + "`n| --- | --- |" + "`n"
        foreach ($class in @($allSpns | Where-Object { $_ -match '^[^/]+' } | ForEach-Object { ($_ -split '/')[0] } | Group-Object | Sort-Object Count -Descending)) {
            $result += "| $($class.Name) | $($class.Count) |" + "`n"
        }

        if ($serviceClassCount -gt 0) {
            $result += "| Computers with SPNs | $(@($computers | Where-Object { @($_.servicePrincipalName | Where-Object { $_ }).Count -gt 0 }).Count) |" + "`n"
        }

        $testResultMarkdown = "Active Directory computer SPNs have been analyzed. $serviceClassCount distinct service classes found across $totalSpnCount SPNs.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
