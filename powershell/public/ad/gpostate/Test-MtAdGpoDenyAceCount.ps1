function Test-MtAdGpoDenyAceCount {
    <#
    .SYNOPSIS
    Counts GPO reports that include a Deny ACE.

    .DESCRIPTION
    This test retrieves GPO state data and counts how many GPO reports indicate that
    a Deny ACE is present.

    .EXAMPLE
    Test-MtAdGpoDenyAceCount

    Returns $true when no GPO reports include a Deny ACE, otherwise $false.
    The test result includes a markdown table with the count.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoDenyAceCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = $null
    try {
        $gpoState = Get-MtADGpoState
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

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

    $sampleLimit = 5
    $sampleGpo = $reportsWithDenyAce | Select-Object -First $sampleLimit
    $sampleNames = @($sampleGpo | ForEach-Object {
        $name = $null
        if ($_.PSObject.Properties.Name -contains 'Name') { $name = $_.Name }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '' }
        $name
    }) | Where-Object { $_ }
    $sampleNamesText = ($sampleNames -join ', ')
    if ($denyAceCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    $resultTable = "| Metric | Value |`n"
    $resultTable += "| --- | --- |`n"
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |`n"
    $resultTable += "| GPO Reports With Deny ACE | $denyAceCount |`n"
    if ($denyAceCount -gt 0 -and $sampleNamesText) {
        $resultTable += "| Sample GPO Reports | $sampleNamesText |`n"
    }

    if ($testResult) {
        $recommendation = '✅ No GPO reports include a Deny ACE.'
    }
    else {
        $recommendation = "⚠️ GPO reports include a Deny ACE ($denyAceCount). Deny ACEs can override expected permissions and require careful review."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}



