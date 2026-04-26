<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoWmiFilterDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs that have a non-empty WMI filter.

    .DESCRIPTION
    This test retrieves Active Directory GPO state data using Get-MtADGpoState and returns a markdown
    table listing all GPOs whose WmiFilter property is configured.

    .EXAMPLE
    Test-MtAdGpoWmiFilterDetails

    Returns $true if GPO state data is accessible, $false otherwise.
    The test result includes a markdown table of GPO WMI filter configuration.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoWmiFilterDetails
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
    if ($null -eq $gpos) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory Group Policy Objects (GPOs) from Get-MtADGpoState.'
        return $false
    }

    $gposArray = @($gpos | Where-Object { $null -ne $_ })

    $wmiFiltered = $gposArray | Where-Object {
        $wf = $_.WmiFilter
        -not [string]::IsNullOrWhiteSpace([string]$wf)
    }

    $wmiFilteredCount = @($wmiFiltered).Count
    $testResult = $true

    $table = "| GPO DisplayName | Id | GpoStatus | WmiFilter | Owner |`n"
    $table += '| --- | --- | --- | --- | --- |' + "`n"

    foreach ($gpo in @($wmiFiltered | Sort-Object -Property DisplayName)) {
        $displayName = [string]$gpo.DisplayName
        $displayName = $displayName -replace '\|', '\\&#124;'

        $id = [string]$gpo.Id
        $owner = if ($null -ne $gpo.Owner) { [string]$gpo.Owner } else { '' }
        $owner = $owner -replace '\|', '\\&#124;'

        $status = if ($null -ne $gpo.GpoStatus) { $gpo.GpoStatus } else { '' }
        $wmiFilter = [string]$gpo.WmiFilter
        $wmiFilter = $wmiFilter -replace '\|', '\\&#124;'

        $table += "| $displayName | $id | $status | $wmiFilter | $owner |`n"
    }

    $recommendation = if ($wmiFilteredCount -gt 0) {
        "GPO WMI filter details were returned ($wmiFilteredCount). Review these filters to ensure they are still intended."
    }
    else {
        '✅ No GPOs with WMI filter configuration were found.'
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}

