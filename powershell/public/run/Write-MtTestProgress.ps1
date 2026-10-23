function Write-MtTestProgress {
    <#
    .SYNOPSIS
    Shows where a long-running test is (its stage, the items done, what it is working on and its errors) in the
    Maester console.

    .DESCRIPTION
    For a test, or the instance source of a family, that runs a tool for a long time and knows how far the tool
    has got: the stage it is in, how many of the items of that stage are done, which items it is working on and
    the errors it reported. Write-MtTestOutput shows the tool's log; this shows the progress that the log is
    hard to read it from.

    In the full-screen dashboard of an interactive run, the progress is a header at the top of the box that
    Write-MtTestOutput opens: the stage, a bar of the items done with the counts, what the work is on now, and
    the newest two errors. Each call replaces the progress of the call before, so pass every part you know
    each time. A call with only -ErrorMessage adds the errors and keeps the progress.

    Otherwise (the compact layout, CI and redirected output) a line is written to the host when the stage
    changes, each error as it comes, and the counts at most every ten seconds.

    A tool that runs in another process, in any language, can report its progress without calling this
    command: a line it writes that Write-MtTestOutput is given, of the form

        ##maester[progress] {"stage":"Exporting data","stageNumber":1,"stageCount":3,"completed":12,"total":40}
        ##maester[error] The export of Users failed: Forbidden

    is passed to this command instead of being shown in the log. The JSON object takes the names of the
    parameters of this command (any case); the parts it leaves out are empty.

    Maester removes the progress when the test or the instance source finishes, with the box.

    .PARAMETER Stage
    The name of the stage the work is in, such as "Exporting tenant data".

    .PARAMETER StageNumber
    The number of the stage, from 1.

    .PARAMETER StageCount
    How many stages there are.

    .PARAMETER Completed
    The items of the stage that are done.

    .PARAMETER Total
    The items of the stage. With a total the header shows a bar.

    .PARAMETER Failed
    The items of the stage that failed.

    .PARAMETER Running
    The items of the stage that are running now.

    .PARAMETER Current
    What the work is on now, such as the names of the items running.

    .PARAMETER Status
    A line of status that fits no other part, such as "Waiting for the throttling limit".

    .PARAMETER ErrorMessage
    Errors the work reported. They are listed under the progress, newest last, and counted on the box.

    .PARAMETER Clear
    Removes the progress and the errors from the box.

    .EXAMPLE
    Write-MtTestProgress -Stage 'Exporting tenant data' -StageNumber 1 -StageCount 3 -Completed 12 -Total 40 -Running 2 -Current 'Users', 'Groups'

    Shows that the work is in the first of three stages, with 12 of its 40 items done and two running.

    .EXAMPLE
    Write-MtTestProgress -ErrorMessage 'The export of Devices failed: Forbidden'

    Adds an error to the box, keeping the progress.

    .EXAMPLE
    & pwsh -NoProfile -File ./Collect.ps1 2>&1 | Write-MtTestOutput -Title 'Collecting the tenant data'

    The script writes lines such as '##maester[progress] {"stage":"Exporting","completed":3,"total":9}' to
    standard output; they set the progress, and its other lines are shown in the box.

    .LINK
    https://maester.dev/docs/commands/Write-MtTestProgress
    #>
    [CmdletBinding(DefaultParameterSetName = 'Progress')]
    param(
        [Parameter(ParameterSetName = 'Progress')]
        [AllowEmptyString()]
        [string] $Stage,

        [Parameter(ParameterSetName = 'Progress')]
        [int] $StageNumber,

        [Parameter(ParameterSetName = 'Progress')]
        [int] $StageCount,

        [Parameter(ParameterSetName = 'Progress')]
        [int] $Completed,

        [Parameter(ParameterSetName = 'Progress')]
        [int] $Total,

        [Parameter(ParameterSetName = 'Progress')]
        [int] $Failed,

        [Parameter(ParameterSetName = 'Progress')]
        [int] $Running,

        [Parameter(ParameterSetName = 'Progress')]
        [AllowEmptyCollection()]
        [string[]] $Current,

        [Parameter(ParameterSetName = 'Progress')]
        [AllowEmptyString()]
        [string] $Status,

        [Parameter(ParameterSetName = 'Progress')]
        [string[]] $ErrorMessage,

        [Parameter(Mandatory, ParameterSetName = 'Clear')]
        [switch] $Clear
    )

    Write-Verbose "Write-MtTestProgress: Stage=$Stage Completed=$Completed Total=$Total Errors=$(@($ErrorMessage).Count) Clear=$Clear"
    $renderer = $script:__MtConsoleRenderer
    $dashboard = $renderer -and $renderer.IsFullScreen
    if (-not $script:__MtTestOutput) { $script:__MtTestOutput = @{ Title = $null; LastProgress = $null } }
    $state = $script:__MtTestOutput
    # Showing the progress must never fail the test.
    try {
        if ($Clear) {
            if ($dashboard) { $renderer.SetOutputProgress($null) }
            $state.Stage = $null
            $state.LastCounts = $null
            return
        }
        $parts = 'Stage', 'StageNumber', 'StageCount', 'Completed', 'Total', 'Failed', 'Running', 'Current', 'Status'
        $hasProgress = [bool]($parts | Where-Object { $PSBoundParameters.ContainsKey($_) })
        $progress = $null
        if ($hasProgress) {
            $progress = [Maester.Engine.MtOutputProgress]@{
                Stage = $Stage; StageNumber = $StageNumber; StageCount = $StageCount
                Completed = $Completed; Total = $Total; Failed = $Failed; Running = $Running
                Current = [string[]]@($Current | Where-Object { $_ }); Status = $Status
            }
        }
        $errors = @($ErrorMessage | Where-Object { $_ })

        if ($dashboard) {
            if ($progress) { $renderer.SetOutputProgress($progress) }
            foreach ($e in $errors) { $renderer.AddOutputError($e) }
            return
        }

        $console = if ($__MtSession -and $__MtSession.Console) { $__MtSession.Console } else { Get-MtConsoleMode }
        $write = {
            param($text, $style)
            $plain = [Maester.Engine.MtConsoleRenderer]::OutputText(($text -replace '[\r\n]+', ' ')).Trim()
            if ($plain) { Write-MtHostLine (Format-MtConsoleText "    $(ConvertTo-MtConsoleSafeText $plain -Console $console)" -Style $style -Console $console) }
        }
        if ($progress) {
            $clean = $progress.Clean()
            $stageText = if ($clean.StageNumber -gt 0) {
                $number = if ($clean.StageCount -ge $clean.StageNumber) { "Stage $($clean.StageNumber) of $($clean.StageCount)" } else { "Stage $($clean.StageNumber)" }
                if ($clean.Stage) { "$number · $($clean.Stage)" } else { $number }
            } else { $clean.Stage }
            if ($stageText -and $stageText -ne $state.Stage) {
                $state.Stage = $stageText
                $state.LastCounts = $null
                & $write $stageText 'Bold'
            }
            $counts = @()
            if ($clean.Total -gt 0) { $counts += "$($clean.Completed) / $($clean.Total)" } elseif ($clean.Completed -gt 0) { $counts += "$($clean.Completed) done" }
            if ($clean.Failed -gt 0) { $counts += "$($clean.Failed) failed" }
            if ($clean.Running -gt 0) { $counts += "$($clean.Running) running" }
            if ($counts -and (-not $state.LastCounts -or $state.LastCounts.Elapsed.TotalSeconds -ge 10)) {
                $state.LastCounts = [System.Diagnostics.Stopwatch]::StartNew()
                & $write ($counts -join ' · ') 'Dim'
            }
        }
        foreach ($e in $errors) { & $write "Error: $e" 'Failed' }
    } catch {
        Write-Debug "Test progress could not be shown: $_"
    }
}
