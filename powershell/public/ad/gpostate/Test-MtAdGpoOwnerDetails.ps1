<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoOwnerDetails {
    <#
    .SYNOPSIS
    Returns details of GPO owners, including how many GPOs each owner has.

    .DESCRIPTION
    This test retrieves Active Directory GPO state data using Get-MtADGpoState and returns a markdown
    table summarizing GPO owners. Owners are grouped by the GPO Owner property.

    .EXAMPLE
    Test-MtAdGpoOwnerDetails

    Returns $true if GPO state data is accessible, $false otherwise.
    The test result includes a markdown table with owner counts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoOwnerDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoOwnerDetails"
    $gpoState = Get-MtADGpoState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo owner details"

    $gpos = $gpoState.GPOs
    if ($null -eq $gpos) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory Group Policy Objects (GPOs) from Get-MtADGpoState.'
        return $false
    }

    $gposArray = @($gpos | Where-Object { $null -ne $_ })

    $rows = $gposArray |
    ForEach-Object {
        $ownerValue = $_.Owner
        if ([string]::IsNullOrWhiteSpace([string]$ownerValue)) { return $null }
        [PSCustomObject]@{
            Owner       = [string]$ownerValue
            DisplayName = [string]$_.DisplayName
        }
    } |
    Where-Object { $null -ne $_ } |
    Group-Object -Property Owner

    $ownerGroups = @($rows)
    $ownerGroupCount = $ownerGroups.Count
    $testResult = $true

    $table = "| Owner | GPO Count | GPO DisplayNames |`n"
    $table += '| --- | --- | --- |' + "`n"

    foreach ($group in ($ownerGroups | Sort-Object -Property Count -Descending)) {
        $owner = [string]$group.Name
        $owner = $owner -replace '\|', '\\&#124;'

        $displayNames = @($group.Group | ForEach-Object { [string]$_.DisplayName } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $displayNamesJoined = ($displayNames | Sort-Object | ForEach-Object { $_ -replace '\|', '\\&#124;' }) -join ', '

        $table += "| $owner | $($group.Count) | $displayNamesJoined |`n"
    }

    $recommendation = if ($ownerGroupCount -gt 0) {
        "GPO owner details were returned for $ownerGroupCount distinct owner(s)."
    } else {
        '✅ No GPO owner values were found.'
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoOwnerDetails"
    return $testResult
}



