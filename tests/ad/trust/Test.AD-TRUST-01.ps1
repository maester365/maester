function Test-MtAdTrustTotalCount {
    <#
    .SYNOPSIS
    Counts the total number of Active Directory trusts.

    .DESCRIPTION
    This test retrieves the total count of domain trusts configured in Active Directory.
    Domain trusts allow authentication and resource access between domains, and knowing
    the number of trusts is essential for security assessment and trust relationship management.

    .EXAMPLE
    Test-MtAdTrustTotalCount

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes the total count of trusts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustTotalCount
    #>
    [MaesterTest(
        Id = 'AD-TRUST-01',
        Title = 'Trust count and configuration should be investigated',
        Product = 'ad',
        Feature = 'trusts',
        Area = 'external-access',
        ResourceType = 'Trust',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:trustedDomain:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdTrustTotalCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Trusts')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        throw 'Active Directory trust inventory was not returned.'
    }

    $trusts = $adState.Trusts
    if ($null -eq $trusts) { throw 'Active Directory trusts were not returned.' }

    # Count total trusts
    $totalCount = ($trusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $null -ne $adState.Trusts

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n" + "`n"
    if ($totalCount -gt 0) {
        $result += "| Target | Direction | Type | Within forest | Quarantined | Selective authentication |`n"
        $result += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($trust in $trusts) {
            $bits = $trust.TrustAttributes
            $withinForest = if ($null -eq $bits) { 'Unknown' } elseif (([int]$bits -band 0x20) -ne 0) { 'Yes' } else { 'No' }
            $quarantined = if ($null -eq $bits) { 'Unknown' } elseif (([int]$bits -band 0x4) -ne 0) { 'Yes' } else { 'No' }
            $selective = if ($null -eq $bits) { 'Unknown' } elseif (([int]$bits -band 0x10) -ne 0) { 'Yes' } else { 'No' }
            $result += "| $($trust.TrustPartner) | $($trust.Direction) | $($trust.TrustTypeName) | $withinForest | $quarantined | $selective |`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No Active Directory trusts are configured in this domain. This is typical for single-domain environments.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Active Directory trust relationships have been analyzed. There are $totalCount trust(s) configured in this domain.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
