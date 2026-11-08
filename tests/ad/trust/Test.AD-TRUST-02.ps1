function Test-MtAdTrustInterForestCount {
    <#
    .SYNOPSIS
    Counts the number of inter-forest trusts in Active Directory.

    .DESCRIPTION
    This test retrieves the count of inter-forest (external) trusts configured in Active Directory.
    Inter-forest trusts connect different Active Directory forests and have different security
    implications than intra-forest trusts. These trusts may be less secure and require careful monitoring.

    .EXAMPLE
    Test-MtAdTrustInterForestCount

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes the count of inter-forest trusts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustInterForestCount
    #>
    [MaesterTest(
        Id = 'AD-TRUST-02',
        Title = 'Trust inter-forest count should be investigated',
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

    Write-Verbose "Starting Test-MtAdTrustInterForestCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Trusts')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        throw 'Active Directory trust inventory was not returned.'
    }

    $trusts = $adState.Trusts
    if ($null -eq $trusts) { throw 'Active Directory trusts were not returned.' }

    # Count inter-forest trusts
    $interForestTrusts = $trusts | Where-Object { $null -ne $_.TrustAttributes -and (([int]$_.TrustAttributes -band 0x20) -eq 0) }
    $interForestCount = ($interForestTrusts | Measure-Object).Count
    $totalCount = ($trusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n"
    $result += "| Inter-Forest Trusts | $interForestCount |" + "`n"
    $result += "| Within-Forest Trusts | $(($trusts | Where-Object { $null -ne $_.TrustAttributes -and ([int]$_.TrustAttributes -band 0x20) -ne 0 } | Measure-Object).Count) |" + "`n"
    $result += "| Unknown classification | $(($trusts | Where-Object { $null -eq $_.TrustAttributes } | Measure-Object).Count) |" + "`n" + "`n"

    if ($interForestCount -eq 0) {
        $testResultMarkdown = "No outside-forest trusts were identified from available trust attributes. Review unknown classifications separately.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "There are $interForestCount inter-forest trust(s) configured. Inter-forest trusts connect to external forests and should be carefully monitored for security.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
