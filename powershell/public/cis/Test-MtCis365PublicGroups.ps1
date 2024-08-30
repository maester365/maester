<#
.SYNOPSIS
    Checks if there are public groups

.DESCRIPTION
    Ensure that only organizationally managed and approved public groups exist
    CIS Microsoft 365 Foundations Benchmark v3.1.0

.EXAMPLE
    Test-MtCis365PublicGroups

    Returns true if no public Microsoft 365 groups are found

.LINK
    https://maester.dev/docs/commands/Test-MtCis365PublicGroups
#>
function Test-MtCis365PublicGroups {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose "Getting all Microsoft 365 Groups"
    $365Groups = Invoke-MtGraphRequest -RelativeUri "groups" -ApiVersion v1.0

    Write-Verbose "Filtering out private 365 groups"
    $result = $365Groups | Where-Object { $_.visibility -eq "Public" }

    $testResult = ($result | Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no public 365 groups:`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant has 1 or more public 365 groups:`n`n%TestResult%"
    }

    $resultMd = "| Display Name | Public Groups |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $365Groups) {
        $itemResult = "❌ Fail"
        if ($item.id -notin $result.id) {
            $itemResult = "✅ Pass"
        }
        $resultMd += "| $($item.displayName) | $($itemResult) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
