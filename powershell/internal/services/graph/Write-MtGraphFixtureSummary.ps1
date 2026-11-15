function Write-MtGraphFixtureSummary {
    <#
    .SYNOPSIS
    Internal: Says at the end of a run what Graph record or replay did, and warns about every request that had no fixture.

    .DESCRIPTION
    Invoke-Maester calls this once the reports are written. After a recording it updates the fixture set's
    index.json. After a replay with missing fixtures it writes one warning that lists them, so that a test that
    ended in an error because its data was missing is never mistaken for a real result.

    .EXAMPLE
    Write-MtGraphFixtureSummary

    Writes the summary of the current run, if record or replay is on.
    #>
    [CmdletBinding()]
    param()

    $state = $__MtSession.GraphFixture
    if (-not $state) { return }

    if ($state.Mode -eq 'Record') {
        $null = Update-MtGraphFixtureIndex -Path $state.Path -Scenario $state.Name
        Write-Verbose "Graph record: $($state.Recorded) response(s) written to '$($state.Folder)'."
        return
    }

    Write-Verbose "Graph replay: $($state.Served) response(s) served from '$($state.Folder)'."
    if ($state.Unsupported.Count -gt 0) {
        Write-Verbose ("Graph replay skipped the tests that call Invoke-MgGraphRequest directly: " + (@($state.Unsupported.Keys) -join ', '))
    }
    if ($state.Missing.Count -gt 0) {
        $lines = @($state.Missing.Values | ForEach-Object { "  $($_.Key)  ->  $($_.File)" })
        $intro = "Graph replay: {0} request(s) had no fixture in '{1}', so the tests that made them did not get their data." -f $state.Missing.Count, $state.Folder
        Write-Warning ("$intro Record them, or write them with New-MtGraphFixture. Get-MtGraphFixtureStatus lists them too.`n" + ($lines -join "`n"))
    }
}
