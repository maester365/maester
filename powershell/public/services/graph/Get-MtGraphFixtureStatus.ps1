function Get-MtGraphFixtureStatus {
    <#
    .SYNOPSIS
    Shows whether Graph record or replay is on, and lists the requests that had no fixture.

    .DESCRIPTION
    Returns the mode (Off, Record or Replay), the fixture set, whether recording sanitises, how many responses were
    recorded or replayed, and Missing: every request since the start of the last Invoke-Maester run (or since
    Enable-MtGraphFixture) that had no fixture, with the file that would answer it and how often it was asked for.
    Unsupported lists the requests replay cannot answer at all, because they were sent with Invoke-MgGraphRequest
    directly instead of through Invoke-MtGraphRequest; their tests are skipped.

    Use it after an offline run to see which fixtures to record or write, or in a pipeline to fail when any is missing.

    .EXAMPLE
    (Get-MtGraphFixtureStatus).Missing | Format-Table Key, File, Count

    Lists the requests of the run that replay could not answer.

    .LINK
    https://maester.dev/docs/commands/Get-MtGraphFixtureStatus
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $state = $__MtSession.GraphFixture
    Write-Verbose "Graph record and replay: $(if ($state) { "$($state.Mode), fixture set '$($state.Folder)'" } else { 'Off' })."
    if (-not $state) {
        return [pscustomobject]@{ PSTypeName = 'Maester.GraphFixtureStatus'; Mode = 'Off'; Path = $null; Scenario = $null; Folder = $null; Sanitize = $null; Recorded = 0; Served = 0; MissingCount = 0; Missing = @(); Unsupported = @() }
    }
    [pscustomobject]@{
        PSTypeName   = 'Maester.GraphFixtureStatus'
        Mode         = $state.Mode
        Path         = $state.Path
        Scenario     = $state.Name
        Folder       = $state.Folder
        Sanitize     = if ($state.Mode -eq 'Record') { [bool]$state.Sanitize } else { $null }
        Recorded     = $state.Recorded
        Served       = $state.Served
        MissingCount = $state.Missing.Count
        Missing      = @($state.Missing.Values)
        Unsupported  = @($state.Unsupported.Values)
    }
}
