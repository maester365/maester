function Test-MtCisTrustedNamedLocations {
    <#
    .SYNOPSIS
        Checks that at least one trusted IP named location with ranges is defined.

    .DESCRIPTION
        Checks that at least one IP-based named location in Conditional Access has IP ranges and is marked as trusted, so that policies can treat sign-ins from your known networks differently.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.14, L2)

    .EXAMPLE
        Test-MtCisTrustedNamedLocations

        Returns true if at least one trusted IP named location with ranges exists.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.14
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.14',
        Title = 'Ensure trusted ''named locations'' are defined',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:5.2.2.14', 'nist-800-53-r5:AC-3'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting named locations...'
    $locations = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/namedLocations' -DisableCache
    $ipLocations = @($locations | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.ipNamedLocation' })

    $report = foreach ($location in $ipLocations) {
        $rangeCount = @($location.ipRanges).Count
        [pscustomobject]@{
            Name = $location.displayName
            Ranges = $rangeCount
            Trusted = [bool]$location.isTrusted
            Pass = $rangeCount -gt 0 -and $location.isTrusted -eq $true
        }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0

    $passText = 'At least one trusted IP named location with IP ranges is defined.'
    $failText = if ($ipLocations.Count -eq 0) { 'No IP named locations are defined.' } else { 'No IP named location is both trusted and has IP ranges.' }

    $resultMd = "| Named location | IP ranges | Trusted | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Name) | $($row.Ranges) | $($row.Trusted) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
