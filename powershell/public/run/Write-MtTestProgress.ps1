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
    The items of the stage that are done and did not fail.

    .PARAMETER Total
    The items of the stage. With a total the header shows a bar of the items done (completed and failed), the
    percentage, and the time left once there is something to go on.

    .PARAMETER Failed
    The items of the stage that failed.

    .PARAMETER Running
    The items of the stage that are running now.

    .PARAMETER Current
    What the work is on now, such as the names of the items running.

    .PARAMETER Status
    A line of status that fits no other part, such as "Waiting for the throttling limit".

    .PARAMETER Stages
    The names of all the stages, in order. The header draws them as a track, like the phases of a Maester run:
    the stages before -StageNumber done, that one running, the others to come.

    .PARAMETER Items
    The items running and the ones that finished last (such as the exports or tests of a tool), shown the way
    the dashboard shows Maester's own tests: the ones running with a spinner and the time they have run, the
    ones that finished with their result and how long they took. Each is a hashtable or object with Id, and
    optionally Title, Status (Running, Passed, Failed, TimedOut or Skipped; Running when left out), Detail
    (what it is doing, or why it failed) and Seconds. Outside the dashboard each item that finished is written
    once, with its result and time.

    .PARAMETER Results
    The results of the work so far, when it is a tool that runs tests of its own: a hashtable or object with
    Passed, Failed, Error, Investigate, Skipped, Running and Total, and optionally Name. While the box is open the
    dashboard shows them in place of Maester's own: in its Results panel, under Name (or the title of the box),
    and, before Maester's tests start, as a block for each item over the box.

    .PARAMETER Groups
    The results by group, such as the pillars of an assessment: each a hashtable or object with Name and the
    counts of -Results. While the box is open the dashboard lists them where it lists the products, with a bar
    and the counts of each.

    .PARAMETER GroupLabel
    What the groups are called, such as "Pillars": the title of the box that lists them.

    .PARAMETER ErrorMessage
    Errors the work reported. They are listed under the progress, newest last, and counted on the box.

    .PARAMETER Clear
    Removes the progress and the errors from the box.

    .EXAMPLE
    Write-MtTestProgress -Stage 'Exporting tenant data' -StageNumber 1 -StageCount 3 -Completed 12 -Total 40 -Running 2 -Current 'Users', 'Groups'

    Shows that the work is in the first of three stages, with 12 of its 40 items done and two running.

    .EXAMPLE
    Write-MtTestProgress -Stage 'Running tests' -Results @{ Passed = 80; Failed = 12; Total = 300; Running = 4 } -GroupLabel 'Pillars' -Groups @{ Name = 'Identity'; Passed = 50; Failed = 8; Total = 120 }, @{ Name = 'Devices'; Passed = 30; Failed = 4; Total = 90 }

    Shows the results of the tool's own tests in the dashboard's Results panel and result blocks, and its
    pillars where the products are listed.

    Each item that finishes with a time (in -Items, in any stage) is also kept: while the box is open the Pace
    graph next to the logo draws how long each took, and the Slowest panel lists the slowest.

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
        [AllowEmptyCollection()]
        [string[]] $Stages,

        [Parameter(ParameterSetName = 'Progress')]
        [AllowEmptyCollection()]
        [object[]] $Items,

        [Parameter(ParameterSetName = 'Progress')]
        [object] $Results,

        [Parameter(ParameterSetName = 'Progress')]
        [AllowEmptyCollection()]
        [object[]] $Groups,

        [Parameter(ParameterSetName = 'Progress')]
        [AllowEmptyString()]
        [string] $GroupLabel,

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
        $parts = 'Stage', 'StageNumber', 'StageCount', 'Completed', 'Total', 'Failed', 'Running', 'Current', 'Status', 'Stages', 'Items', 'Results', 'Groups', 'GroupLabel'
        $hasProgress = [bool]($parts | Where-Object { $PSBoundParameters.ContainsKey($_) })
        $progress = $null
        # The keys of a hashtable from ConvertFrom-Json -AsHashtable keep their case: find them in any case.
        $read = {
            param($object, $name)
            if ($object -isnot [System.Collections.IDictionary]) { return $object.$name }
            foreach ($key in $object.Keys) { if ([string]$key -eq $name) { return $object[$key] } }
        }
        $toGroup = {
            param($object)
            if ($null -eq $object) { return $null }
            $group = [Maester.Engine.MtOutputGroup]::new()
            $group.Name = [string](& $read $object 'Name')
            foreach ($count in 'Total', 'Passed', 'Failed', 'Error', 'Investigate', 'Skipped', 'Running') {
                $value = & $read $object $count
                if ($null -ne $value -and "$value" -ne '') { $group.$count = [int]$value }
            }
            $group
        }
        if ($hasProgress) {
            $progress = [Maester.Engine.MtOutputProgress]@{
                Stage = $Stage; StageNumber = $StageNumber; StageCount = $StageCount
                Completed = $Completed; Total = $Total; Failed = $Failed; Running = $Running
                Current = [string[]]@($Current | Where-Object { $_ }); Status = $Status
                Stages = [string[]]@($Stages | Where-Object { $_ })
                Results = & $toGroup $Results
                Groups = [Maester.Engine.MtOutputGroup[]]@(foreach ($g in @($Groups | Where-Object { $_ })) { & $toGroup $g })
                GroupLabel = $GroupLabel
                Items = [Maester.Engine.MtOutputItem[]]@(foreach ($item in @($Items | Where-Object { $_ })) {
                        # The keys of a hashtable from ConvertFrom-Json -AsHashtable keep their case: find them in any case.
                        $get = {
                            param($name)
                            if ($item -isnot [System.Collections.IDictionary]) { return $item.$name }
                            foreach ($key in $item.Keys) { if ([string]$key -eq $name) { return $item[$key] } }
                        }
                        $seconds = & $get 'Seconds'
                        [Maester.Engine.MtOutputItem]@{
                            Id = [string](& $get 'Id'); Title = [string](& $get 'Title'); Detail = [string](& $get 'Detail')
                            Status = [string](& $get 'Status'); Seconds = if ($null -ne $seconds -and "$seconds" -ne '') { [double]$seconds } else { -1 }
                        }
                    })
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
            if ($clean.Total -gt 0) { $counts += "$([math]::Min($clean.Completed + $clean.Failed, $clean.Total)) / $($clean.Total)" } elseif ($clean.Completed -gt 0) { $counts += "$($clean.Completed) done" }
            if ($clean.Failed -gt 0) { $counts += "$($clean.Failed) failed" }
            if ($clean.Running -gt 0) { $counts += "$($clean.Running) running" }
            if (-not [string]::IsNullOrWhiteSpace($clean.Status)) { $counts += $clean.Status.Trim() }
            # Each item that finished is written once, as the compact layout writes Maester's own tests.
            if (-not $state.SeenItems) { $state.SeenItems = [System.Collections.Generic.HashSet[string]]::new() }
            foreach ($item in $clean.Items) {
                if ($item.Status -in 'Running', 'Waiting' -or -not $state.SeenItems.Add("$($item.Id)|$($item.Title)")) { continue }
                $unicode = $console -and $console.Unicode
                $mark, $style = switch ($item.Status) {
                    'Failed' { $(if ($unicode) { '✗' } else { 'x' }), 'Failed' }
                    'TimedOut' { '!', 'Error' }
                    'Skipped' { $(if ($unicode) { '–' } else { '-' }), 'Dim' }
                    default { $(if ($unicode) { '✓' } else { '+' }), 'Passed' }
                }
                $name = (@($item.Id, $item.Title) | Where-Object { $_ }) -join ' '
                $time = if ($item.Seconds -ge 0) { '  ' + (Format-MtDuration ([timespan]::FromSeconds($item.Seconds))) } else { '' }
                $why = if ($item.Status -in 'Failed', 'TimedOut' -and $item.Detail) { ": $($item.Detail)" } else { '' }
                & $write "$mark $name$why$time" $style
            }
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
