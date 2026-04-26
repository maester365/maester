function Test-MtAdDaclDistinctObjectCount {
    <#
    .SYNOPSIS
    Counts distinct Active Directory objects that have DACL entries.

    .DESCRIPTION
    This informational test reviews DACL data collected by Get-MtADDomainState and counts the
    number of unique Active Directory objects represented in the DACL dataset. This helps confirm
    the breadth of DACL coverage across collected objects and provides baseline visibility into how
    many objects have explicit or inherited access control entries available for analysis.

    .EXAMPLE
    Test-MtAdDaclDistinctObjectCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclDistinctObjectCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Active Directory.'
        return $null
    }

    $daclEntries = @($adState.DaclEntries)
    $distinctObjects = @(
        $daclEntries |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
            Select-Object -ExpandProperty ObjectDN -Unique
    )

    $daclEntryCount = ($daclEntries | Measure-Object).Count
    $distinctObjectCount = ($distinctObjects | Measure-Object).Count
    $averageAcePerObject = if ($distinctObjectCount -gt 0) {
        [Math]::Round($daclEntryCount / $distinctObjectCount, 2)
    }
    else {
        0
    }

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total DACL Entries | $daclEntryCount |`n"
    $result += "| Distinct Objects With DACL Entries | $distinctObjectCount |`n"
    $result += "| Average ACEs Per Object | $averageAcePerObject |`n"

    $testResultMarkdown = "Active Directory DACL data has been analyzed. $distinctObjectCount distinct object(s) have one or more DACL entries available for review.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}


