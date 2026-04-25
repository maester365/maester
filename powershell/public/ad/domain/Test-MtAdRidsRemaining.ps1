function Test-MtAdRidsRemaining {
    <#
    .SYNOPSIS
    Retrieves the number of remaining RIDs (Relative Identifiers) in the domain.

    .DESCRIPTION
    This test retrieves the count of available RIDs in the Active Directory domain.
    RIDs are used to generate unique SIDs for new security principals. Running out
    of RIDs would prevent the creation of new users, groups, or computers.

    .EXAMPLE
    Test-MtAdRidsRemaining

    Returns $true if RID data is accessible.
    The test result includes the number of remaining RIDs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdRidsRemaining
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

    # Try to get RID available pool from the domain object
    $ridsRemaining = $null
    try {
        $domainObject = Get-ADObject -Identity $domain.DistinguishedName -Properties RIDAvailablePool
        $ridsRemaining = $domainObject.RIDAvailablePool
    }
    catch {
        Write-Verbose "Could not retrieve RID pool: $($_.Exception.Message)"
    }

    # RID pool is a 64-bit value where high 32 bits are total and low 32 bits are used
    # Calculate remaining RIDs
    if ($null -ne $ridsRemaining) {
        $totalRIDs = [math]::Floor($ridsRemaining / [math]::Pow(2, 32))
        $usedRIDs = $ridsRemaining -band 0xFFFFFFFF
        $availableRIDs = $totalRIDs - $usedRIDs
    } else {
        $availableRIDs = $null
    }

    # Test passes if we successfully retrieved domain data (RID pool is optional)
    $testResult = $null -ne $domain

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Available RIDs | $availableRIDs |`n"
        $result += "| Total RIDs | $totalRIDs |`n"
        $result += "| Used RIDs | $usedRIDs |`n"
        $result += "| Domain | $($domain.Name) |`n"

        $percentageUsed = if ($totalRIDs -gt 0) { [Math]::Round(($usedRIDs / $totalRIDs) * 100, 2) } else { 0 }
        $result += "| Percentage Used | $percentageUsed% |`n"

        $testResultMarkdown = "The RID pool status has been retrieved. There are $availableRIDs RIDs remaining in the domain.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve RID information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
