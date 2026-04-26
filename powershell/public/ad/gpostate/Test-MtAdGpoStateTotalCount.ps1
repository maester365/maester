<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoStateTotalCount {
    <#
    .SYNOPSIS
    Counts the total number of Group Policy Objects (GPOs) returned by Get-MtADGpoState.

    .DESCRIPTION
    This test retrieves Active Directory GPO state data using Get-MtADGpoState and counts the total
    number of GPO entries present in the returned state.

    .EXAMPLE
    Test-MtAdGpoStateTotalCount

    Returns $true if GPO state data is accessible, $false otherwise.
    The test result includes the total number of returned GPOs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoStateTotalCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoStateTotalCount"
    $gpoState = Get-MtADGpoState
    Write-Verbose "Retrieved AD state"

    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo state total count"

    $gpos = $gpoState.GPOs
    if ($null -eq $gpos) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory Group Policy Objects (GPOs) from Get-MtADGpoState.'
        return $false
    }

    $totalCount = @($gpos | Where-Object { $null -ne $_ }).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs (state) | $totalCount |`n"
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory GPO state has been analyzed. The domain contains $totalCount GPO(s) (state view).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoStateTotalCount"
    return $testResult
}


