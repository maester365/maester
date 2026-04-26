function Test-MtAdGpoDenyAceDetails {
    <#
    .SYNOPSIS
    Returns details of GPO reports that include a Deny ACE.

    .DESCRIPTION
    This test retrieves GPO state data and returns a markdown table listing the GPO
    reports where a Deny ACE is present.

    .EXAMPLE
    Test-MtAdGpoDenyAceDetails

    Returns $true when no GPO reports include a Deny ACE, otherwise $false.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoDenyAceDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoDenyAceDetails"
    $gpoState = $null
    try {
        $gpoState = Get-MtADGpoState
    Write-Verbose "Retrieved AD state"
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo deny ace details"

    $gpoReports = $null
    if ($gpoState.PSObject.Properties.Name -contains 'GPOReports') {
        $gpoReports = $gpoState.GPOReports
    }
    elseif ($gpoState.PSObject.Properties.Name -contains 'GpoReports') {
        $gpoReports = $gpoState.GpoReports
    }
    else {
        $gpoReports = @()
        foreach ($gpo in @($gpoState.GPOs)) {
            foreach ($prop in @('GpoReports', 'GPOReports', 'GpoReport', 'GPOReport')) {
                if ($gpo.PSObject.Properties.Name -contains $prop -and $null -ne $gpo.$prop) {
                    $value = $gpo.$prop
                    if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                        $gpoReports += @($value)
                    }
                    else {
                        $gpoReports += $value
                    }
                }
            }
        }
    }

    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve GPO reports from Get-MtADGpoState.'
        return $false
    }

    $gpoReports = @($gpoReports)
    $reportsWithDenyAce = @(
        foreach ($report in $gpoReports) {
            $hasDenyAce = $null
            if ($report.PSObject.Properties.Name -contains 'HasDenyAce') {
                $hasDenyAce = $report.HasDenyAce
            }

            if ($hasDenyAce -eq $true) {
                $report
            }
        }
    )

    $denyAceCount = ($reportsWithDenyAce | Measure-Object).Count
    $testResult = $denyAceCount -eq 0

    $table = "| GPO Name | HasDenyAce |`n"
    $table += '| --- | --- |' + "`n"

    foreach ($report in @($reportsWithDenyAce | Sort-Object Name)) {
        $name = if ($null -ne $report.Name) { [string]$report.Name } else { '' }
        $name = $name -replace '\|', '\\&#124;'

        $hasDenyAce = $report.HasDenyAce
        if ($null -eq $hasDenyAce) { $hasDenyAce = '' }
        $table += "| $name | $hasDenyAce |`n"
    }

    $recommendation = if ($testResult) {
        '✅ No GPO reports include a Deny ACE.'
    }
    else {
        "⚠️ GPO reports include a Deny ACE ($denyAceCount)."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoDenyAceDetails"
    return $testResult
}



