function Disable-MtGraphFixture {
    <#
    .SYNOPSIS
    Turns off Graph record or replay, so Maester calls Microsoft Graph as usual again.

    .DESCRIPTION
    Ends the mode Enable-MtGraphFixture turned on. After a recording, the fixture set's index.json is written again
    so that it lists every recorded request. Returns the status of the session that ended: the mode, how many
    responses were recorded or replayed, and the requests that had no fixture.

    .EXAMPLE
    Disable-MtGraphFixture

    Turns off record or replay and returns what it did.

    .LINK
    https://maester.dev/docs/commands/Disable-MtGraphFixture
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $state = $__MtSession.GraphFixture
    if (-not $state) {
        Write-Verbose 'Graph record and replay is not on.'
        return
    }
    if ($state.Mode -eq 'Record') { $null = Update-MtGraphFixtureIndex -Path $state.Path -Scenario $state.Name }
    $status = Get-MtGraphFixtureStatus
    foreach ($name in 'Get-MgContext', 'Invoke-MgGraphRequest') {
        # Remove-Item does not take a scope in a function: path, so the stand-in, found here in the module's scope, is removed by name.
        if (Test-Path -Path "function:script:$name") { Remove-Item -Path "function:$name" }
    }
    $__MtSession.GraphFixture = $null
    # Responses replayed from the fixture set must not answer requests sent to the tenant.
    Clear-MtGraphCache
    return $status
}
