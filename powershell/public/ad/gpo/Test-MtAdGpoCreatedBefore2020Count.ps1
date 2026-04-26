function Test-MtAdGpoCreatedBefore2020Count {
    <#
    .SYNOPSIS
    Counts the number of Group Policy Objects (GPOs) created before 2020 in Active Directory.

    .DESCRIPTION
    This test retrieves Active Directory GPO state information using Get-MtADGpoState, then counts
    the number of GPOs with a CreationTime earlier than January 1st, 2020.

    Knowing how many older GPOs exist helps identify potential legacy policy sprawl that may
    include outdated security settings.

    .EXAMPLE
    Test-MtAdGpoCreatedBefore2020Count

    Returns $true if GPO data is accessible, $false otherwise.

    The test result includes the count of GPOs created before 2020.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoCreatedBefore2020Count
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = Get-MtADGpoState
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpos = $gpoState.GPOs

    $cutoffDate = Get-Date -Year 2020 -Month 1 -Day 1
    $oldGpos = $gpos | Where-Object { $_.CreationTime -lt $cutoffDate }

    $oldCount = ($oldGpos | Measure-Object).Count
    $totalCount = ($gpos | Measure-Object).Count

    $testResult = $totalCount -ge 0

    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| GPOs created before $($cutoffDate.ToString('yyyy-MM-dd')) | $oldCount |`n"
        $result += "| Total GPOs | $totalCount |`n"

        $testResultMarkdown = "Active Directory Group Policy Objects have been analyzed. The domain contains $oldCount GPO(s) created before $($cutoffDate.ToString('yyyy-MM-dd')).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
    }
    else {
        $testResultMarkdown = 'Unable to retrieve Active Directory Group Policy Objects. Ensure you have appropriate permissions and the Group Policy Management Console is installed.'
    }

    # Generate markdown results
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


