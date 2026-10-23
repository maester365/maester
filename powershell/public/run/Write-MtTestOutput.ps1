function Write-MtTestOutput {
    <#
    .SYNOPSIS
    Shows the lines a long-running test writes while it works, live in the Maester console.

    .DESCRIPTION
    For a test, or the instance source of a family, that runs a tool for a long time (for example a command in
    another PowerShell process) and wants the person running Maester to see that tool's log as it runs.

    While the full-screen dashboard of an interactive run has the screen, nothing else can write to the
    console. The lines go into a box in the main column of the dashboard, which scrolls as they come in.
    Otherwise (the compact layout, CI and redirected output) each line is written to the host as it comes,
    indented and dimmed, and a line of -Progress at most every ten seconds. The lines go to the host itself,
    not to the information stream: Write-Host in a test is kept and shown only when the test has finished.

    The box opens with the first line, or with -Title, and closes with -Complete. Maester closes it when the
    test or the instance source finishes.

    .PARAMETER InputObject
    A line to show. Line breaks start new lines. Escape sequences, emoji and other control characters are
    removed.

    .PARAMETER Title
    The title of the box. A new title starts the box again, empty.

    .PARAMETER Progress
    The line is a status that changes (such as "Completed: 12 / 300"). In the dashboard it is pinned at the
    bottom of the box, under the lines that scroll, and the next line of progress replaces it.

    .PARAMETER Complete
    Closes the box.

    .EXAMPLE
    & pwsh -NoProfile -File ./Collect.ps1 2>&1 | Write-MtTestOutput -Title 'Collecting the tenant data'
    Write-MtTestOutput -Complete

    Shows the output of a script that runs in another PowerShell process in the console while it runs.

    .LINK
    https://maester.dev/docs/commands/Write-MtTestOutput
    #>
    [CmdletBinding(DefaultParameterSetName = 'Line')]
    param(
        [Parameter(ParameterSetName = 'Line', Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [object] $InputObject,

        [Parameter(ParameterSetName = 'Line')]
        [string] $Title,

        [Parameter(ParameterSetName = 'Line')]
        [switch] $Progress,

        [Parameter(Mandatory, ParameterSetName = 'Complete')]
        [switch] $Complete
    )

    begin {
        $renderer = $script:__MtConsoleRenderer
        $dashboard = $renderer -and $renderer.IsFullScreen
        $console = if ($__MtSession -and $__MtSession.Console) { $__MtSession.Console } else { Get-MtConsoleMode }
        if ($Complete) {
            if ($renderer) { $renderer.StopOutput() }
            $script:__MtTestOutput = $null
            return
        }
        if (-not $script:__MtTestOutput) { $script:__MtTestOutput = @{ Title = $null; LastProgress = $null } }
        $state = $script:__MtTestOutput
        if ($Title -and $Title -ne $state.Title) {
            $state.Title = $Title
            if ($dashboard) { $renderer.StartOutput($Title) }
            else {
                $heading = ConvertTo-MtConsoleSafeText ([Maester.Engine.MtConsoleRenderer]::OutputText($Title)) -Console $console
                Write-MtHostLine (Format-MtConsoleText "  $heading" -Style Bold -Console $console)
            }
        }
    }

    process {
        if ($Complete -or $null -eq $InputObject) { return }
        # Error records from 2>&1 and the lines of Write-Host come through as objects: their text is what shows.
        $text = if ($InputObject -is [System.Management.Automation.ErrorRecord]) { [string]$InputObject.Exception.Message } else { [string]$InputObject }
        # Showing the output must never fail the test.
        try {
            if ($dashboard) {
                $renderer.WriteOutput($text, [bool]$Progress)
                return
            }
            if ($Progress) {
                if ($state.LastProgress -and $state.LastProgress.Elapsed.TotalSeconds -lt 10) { return }
                $state.LastProgress = [System.Diagnostics.Stopwatch]::StartNew()
            }
            foreach ($line in ($text -split '\r?\n')) {
                $plain = [Maester.Engine.MtConsoleRenderer]::OutputText($line)
                if (-not $plain.Trim()) { continue }
                Write-MtHostLine (Format-MtConsoleText "    $(ConvertTo-MtConsoleSafeText $plain -Console $console)" -Style Dim -Console $console)
            }
        } catch {
            Write-Debug "Test output could not be shown: $_"
        }
    }
}
