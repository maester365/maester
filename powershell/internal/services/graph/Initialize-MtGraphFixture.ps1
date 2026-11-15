function Initialize-MtGraphFixture {
    <#
    .SYNOPSIS
    Internal: Turns on Graph record or replay from the environment, and starts a new list of missing fixtures for a run.

    .DESCRIPTION
    Invoke-Maester and Invoke-MtTest call this before they look at the Graph connection. When Enable-MtGraphFixture
    has not been called in the session and MAESTER_GRAPH_FIXTURE_MODE is Record or Replay, it turns the mode on with
    MAESTER_GRAPH_FIXTURE_PATH, MAESTER_GRAPH_FIXTURE_SCENARIO (default: default) and, when
    MAESTER_GRAPH_FIXTURE_SANITIZE is 0 or false, without sanitising. With the variables unset it does nothing.

    -NewRun clears the counters and the missing fixtures, so that the report at the end of a run is about that run.

    .EXAMPLE
    Initialize-MtGraphFixture -NewRun

    Turns on the mode the environment asks for and starts a new list of missing fixtures.
    #>
    [CmdletBinding()]
    param(
        # Start new counters and a new list of missing fixtures.
        [Parameter()]
        [switch] $NewRun
    )

    if (-not $__MtSession.GraphFixture) {
        $mode = [string]$env:MAESTER_GRAPH_FIXTURE_MODE
        if ($mode -in 'Record', 'Replay') {
            if (-not $env:MAESTER_GRAPH_FIXTURE_PATH) {
                throw "MAESTER_GRAPH_FIXTURE_MODE is '$mode', but MAESTER_GRAPH_FIXTURE_PATH is not set. Set it to the folder of the fixture sets."
            }
            $scenario = if ($env:MAESTER_GRAPH_FIXTURE_SCENARIO) { $env:MAESTER_GRAPH_FIXTURE_SCENARIO } else { 'default' }
            $noSanitize = $env:MAESTER_GRAPH_FIXTURE_SANITIZE -in '0', 'false'
            $null = Enable-MtGraphFixture -Mode $mode -Path $env:MAESTER_GRAPH_FIXTURE_PATH -Scenario $scenario -NoSanitize:$noSanitize
            $__MtSession.GraphFixture.Source = 'Environment'
        } elseif ($mode -and $mode -ne 'Off') {
            Write-Warning "MAESTER_GRAPH_FIXTURE_MODE is '$mode'. Use Record, Replay or Off. Graph record and replay stays off."
        }
    }

    $state = $__MtSession.GraphFixture
    if ($NewRun -and $state) {
        $state.Missing.Clear()
        $state.Unsupported.Clear()
        $state.Served = 0
        $state.Recorded = 0
    }
}
