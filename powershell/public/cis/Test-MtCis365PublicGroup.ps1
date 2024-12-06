<#
.SYNOPSIS
    Checks if there are public groups

.DESCRIPTION
    Ensure that only organizationally managed and approved public groups exist
    CIS Microsoft 365 Foundations Benchmark v3.1.0

.EXAMPLE
    Test-MtCis365PublicGroup

    Returns true if no public Microsoft 365 groups are found

.LINK
    https://maester.dev/docs/commands/Test-MtCis365PublicGroup
#>
function Test-MtCis365PublicGroup {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose "Getting all Microsoft 365 Groups"
    $365GroupList = Invoke-MtGraphRequest -RelativeUri "groups" -ApiVersion v1.0

    Write-Verbose "Filtering out private 365 groups"
    $result = $365GroupList | Where-Object { $_.visibility -eq "Public" }

    $testResult = ($result | Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no public 365 groups:`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant has 1 or more public 365 groups:`n`n%TestResult%"
    }
    # $itemCount is used to limit the number of returned results shown in the table
    $itemCount = 0
    $resultMd = "| Display Name | Group Public |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $result) {
        $itemCount += 1
        $itemResult = "❌ Fail"
        # We are restricting the table output to 6 below as it could be extremely large
        if ($itemCount -lt 7) {
            $resultMd += "| $($item.displayName) | $($itemResult) |`n"
        }
    }
    # Add a limited results message if more than 6 results are returned
    if ($itemCount -gt 6) {
        $resultMd += "Results limited to 6`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
