function Test-MtCis365PublicGroup {
    <#
    .SYNOPSIS
    Checks if there are public groups

    .DESCRIPTION
    Ensure that only organizationally managed and approved public groups exist.
    Only Microsoft 365 (unified) groups are evaluated, matching the CIS audit procedure.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.2.1, L2)

    .EXAMPLE
    Test-MtCis365PublicGroup

    Returns true if no public Microsoft 365 groups are found

    .LINK
    https://maester.dev/docs/commands/Test-MtCis365PublicGroup
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.2.1',
        Title = 'Ensure that only organizationally managed/approved public groups exist',
        Severity = 'Medium',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 2', 'CIS M365 v7.0.0', 'L2'),
        Service = 'Graph',
        Author = 'NZLostboy',
        Contributor = ('thomas-s-schmidt', 'Mynster9361')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting all Microsoft 365 Groups'
    $365GroupList = Invoke-MtGraphRequest -RelativeUri 'groups' -ApiVersion v1.0 -Filter "groupTypes/any(c:c eq 'Unified')"

    Write-Verbose 'Filtering out private 365 groups'
    $result = $365GroupList | Where-Object { $_.visibility -eq 'Public' }

    $testResult = ($result | Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no public 365 groups:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has $(($result | Measure-Object).Count) public 365 groups:`n`n%TestResult%"
    }
    # $itemCount is used to limit the number of returned results shown in the table
    $itemCount = 0
    $resultMd = "| Display Name | Group Public |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $result) {
        $itemCount += 1
        $itemResult = '❌ Fail'
        # We are restricting the table output to 50 below as it could be extremely large
        if ($itemCount -lt 51) {
            $resultMd += "| $(Get-MtSafeMarkdown $item.displayName) | $($itemResult) |`n"
        }
    }
    # Add a limited results message if more than 6 results are returned
    if ($itemCount -gt 50) {
        $resultMd += "Results limited to 50`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
