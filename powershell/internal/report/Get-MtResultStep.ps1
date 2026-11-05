function Get-MtResultStep {
    <#
    .SYNOPSIS
    Builds the Steps and Goals of a result: the defender's path of the run, with each step's status, readiness and
    place in the order.

    .DESCRIPTION
    Implements sections 6 and 7.2 of docs/proposals/defenders-path.md. The steps in scope (Get-MtStepScope) are the
    steps that rows that ran name and their prerequisites at any depth. For each one:

    - Status, from its verifying tests in this run and its measure, checked in this order: NotApplicable (an OnlyWhen
      condition is false, or every verifying test that ran was skipped as NotApplicable), Unknown when an OnlyWhen
      condition can't be read, NotDone (a test failed or the measure is below its threshold), Unknown (a test ended
      as Investigate, Error or Skipped, or the measure couldn't be read), Done (every test that ran passed and the
      measure met its threshold) and NotChecked (no test ran and no measure was read). A test skipped as
      NotApplicable next to tests that gave a result is left out. Reason says why a step is NotApplicable, Unknown
      or NotChecked (section 7.2 of the design, and the result schema).
    - Readiness, for a step that is NotDone, Unknown or NotChecked: Blocked when a Requires step is NotDone, every
      step of a RequiresOneOf group is NotDone, or a Conflicts step is Done (BlockedBy lists them); Unconfirmed when
      not blocked but a prerequisite is Unknown or NotChecked (Unconfirmed lists them); Ready otherwise. A
      NotApplicable prerequisite counts as met, except in a RequiresOneOf group, which leaves it out; a group with no
      step left is met.
    - Rank: Ready, then Unconfirmed, then Blocked, then Done, then NotApplicable; within a group, prerequisites
      before the steps that depend on them, then the highest value first (the highest Get-MtTestPriority of its
      failed tests, plus the values of the NotDone steps that depend on it at any depth), then the ID.
    - Tests: every test the engine knows that names the step (-Inventory) and every row that does, with its Result
      and ReasonCode. A test with no row is NotRun with ReasonCode NotInRun. A family is represented by its instances'
      rows when it has some.
    - Measure, for a step that has one, whether or not it could be read: the figure, its threshold (MinimumShare, or
      the run config's override) and up to -MaxObjects of the objects that fall short.
    - Earlier, for a NotChecked step whose tests an earlier run checked (-LastKnown, from Get-MtPreviousResult).

    Goals lists each goal that has a step in scope, with its steps in scope in catalogue order (prerequisites first)
    and how many are Done, Applicable, Unknown and NotChecked.

    Returns an object with Steps and Goals, or nothing when no row that ran names a step.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Result rows, with Id, Result, ReasonCode, Step, ParentId and the attributes Get-MtTestPriority reads.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $InputObject = @(),

        # The tests the engine knows (the built-in catalog, custom and pack tests), with Id and Step. Defaults to the
        # built-in catalog.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $Inventory,

        # The measures read for this run (Invoke-MtStepMeasure): measure key to Count, Total, Objects, ReadAt and
        # ReasonCode, and optionally ObjectCount when Objects holds only some of them.
        [Parameter()] [AllowNull()] [hashtable] $Measure = @{},

        # The run config turned measures off.
        [Parameter()] [switch] $MeasuresDisabled,

        # Thresholds from the run config (Measures.MinimumShare), by measure key.
        [Parameter()] [AllowNull()] [hashtable] $MinimumShare = @{},

        # The tenant context, for OnlyWhen conditions: HybridIdentity and Licenses.
        [Parameter()] [AllowNull()] [object] $TenantContext,

        # The newest earlier result of each test ID (Get-MtPreviousResult -LastKnownId): ID to Result, ExecutedAt, File.
        [Parameter()] [AllowNull()] [object] $LastKnown,

        # The most objects a step's Measure keeps.
        [Parameter()] [int] $MaxObjects = 100,

        # The step catalogue. Defaults to the module's.
        [Parameter()] [object] $Catalog = (Get-MtStepCatalog),

        # The measure registry, for each measure's Caveat. Defaults to the module's.
        [Parameter()] [object] $Registry = (Get-MtMeasureRegistry)
    )

    $scope = Get-MtStepScope -InputObject $InputObject -Catalog $Catalog
    if ($scope.Named.Count -eq 0) { return }
    if ($null -eq $Inventory) { $Inventory = @(Get-MtTestCatalog) }
    if ($null -eq $Measure) { $Measure = @{} }
    if ($null -eq $MinimumShare) { $MinimumShare = @{} }
    $ordinal = [System.StringComparer]::Ordinal
    $catalogSteps = $Catalog.Steps
    $inScope = [System.Collections.Generic.HashSet[string]]::new([string[]]$scope.Steps, $ordinal)
    $stepsOf = {
        param($item)
        $p = $item.PSObject.Properties['Step']
        if (-not $p) { return @() }
        @($p.Value | Where-Object { $_ } | ForEach-Object { ([string]$_).ToLowerInvariant() })
    }
    # A property of an object, or a key of a dictionary (a measure reading may be either).
    $field = {
        param($item, $name)
        if ($null -eq $item) { return $null }
        if ($item -is [System.Collections.IDictionary]) { if ($item.Contains($name)) { return , $item[$name] } else { return $null } }
        $p = $item.PSObject.Properties[$name]
        if ($p) { , $p.Value } else { $null }
    }

    # Rows and known tests by step.
    $rowsByStep = @{}
    $rowById = @{}
    $parentsWithRows = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $InputObject) {
        if ($null -eq $row) { continue }
        if ($row.Id -and -not $rowById.ContainsKey([string]$row.Id)) { $rowById[[string]$row.Id] = $row }
        $parent = & $field $row 'ParentId'
        if ($parent) { $null = $parentsWithRows.Add([string]$parent) }
        foreach ($id in (& $stepsOf $row)) {
            if (-not $inScope.Contains($id)) { continue }
            if (-not $rowsByStep.ContainsKey($id)) { $rowsByStep[$id] = [System.Collections.Generic.List[object]]::new() }
            $rowsByStep[$id].Add($row)
        }
    }
    $testsByStep = @{}
    foreach ($t in @($Inventory | Where-Object { $_ -and $_.Id })) {
        foreach ($id in (& $stepsOf $t)) {
            if (-not $inScope.Contains($id)) { continue }
            if (-not $testsByStep.ContainsKey($id)) { $testsByStep[$id] = [System.Collections.Generic.List[object]]::new() }
            $testsByStep[$id].Add($t)
        }
    }

    # OnlyWhen: True, False or Unknown.
    $conditionOf = {
        param([string] $condition)
        if ($condition -eq 'hybrid-identity') {
            $hybrid = if ($TenantContext) { & $field $TenantContext 'HybridIdentity' } else { $null }
            if ($null -eq $hybrid) { return 'Unknown' }
            return $(if ($hybrid) { 'True' } else { 'False' })
        }
        if ($condition -like 'license:*') {
            $licenses = if ($TenantContext) { & $field $TenantContext 'Licenses' } else { $null }
            if (-not $licenses -or [string]$licenses.State -ne 'Known') { return 'Unknown' }
            return $(if (Test-MtLicenseRequirement -Requirement @($condition.Substring(8)) -Licenses $licenses) { 'True' } else { 'False' })
        }
        'Unknown'
    }

    # The measure of a step, in the shape of the result.
    $measureOf = {
        param($step)
        $m = $step.Measure
        $key = $m.Key
        $entry = $null
        $caveat = if ($Registry.Measures.TryGetValue($key, [ref] $entry) -and $entry.Caveat) { $entry.Caveat } else { $null }
        $minimum = [int]$m.MinimumShare
        if ($MinimumShare.ContainsKey($key) -and $null -ne $MinimumShare[$key]) { $minimum = [int]$MinimumShare[$key] }
        $out = [ordered]@{
            Key = $key; Count = $null; Total = $null; Share = $null; MinimumShare = $minimum; Met = $null; ReadAt = $null
            Caveat = $caveat; ObjectCount = $null; Objects = @(); ReasonCode = $null
        }
        $reading = if ($Measure.ContainsKey($key)) { $Measure[$key] } else { $null }
        if ($MeasuresDisabled) { $out.ReasonCode = 'MeasureOff' }
        elseif ($null -eq $reading) { $out.ReasonCode = 'NotRead' }
        else {
            $out.ReadAt = & $field $reading 'ReadAt'
            $code = & $field $reading 'ReasonCode'
            if ($code) { $out.ReasonCode = [string]$code }
            else {
                $count = [int](& $field $reading 'Count')
                $total = [int](& $field $reading 'Total')
                $objects = @(& $field $reading 'Objects' | ForEach-Object { $_ } | Where-Object { $null -ne $_ })
                $objectCount = & $field $reading 'ObjectCount'
                $out.Count = $count
                $out.Total = $total
                $out.Share = if ($total -gt 0) { [int][math]::Floor($count * 100.0 / $total) } else { $null }
                # Compared without rounding: 94.9% does not meet 95%. No object to count meets nothing.
                $out.Met = $total -gt 0 -and ($count * 100.0) -ge ($minimum * $total)
                $out.ObjectCount = if ($null -ne $objectCount) { [int]$objectCount } else { $objects.Count }
                $out.Objects = @($objects | Select-Object -First $MaxObjects | ForEach-Object {
                        [pscustomobject][ordered]@{ Type = [string](& $field $_ 'Type'); Id = [string](& $field $_ 'Id'); DisplayName = [string](& $field $_ 'DisplayName') }
                    })
            }
        }
        [pscustomobject]$out
    }

    # Status of each step in scope.
    $status = @{}
    $records = [ordered]@{}
    foreach ($id in $scope.Steps) {
        $step = $catalogSteps[$id]
        $rows = if ($rowsByStep.ContainsKey($id)) { @($rowsByStep[$id]) } else { @() }

        # Tests: the rows, and the known tests with no row.
        $tests = [System.Collections.Generic.List[object]]::new()
        $listed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($row in $rows) {
            if (-not $row.Id -or -not $listed.Add([string]$row.Id)) { continue }
            $tests.Add([pscustomobject][ordered]@{ Id = [string]$row.Id; Result = [string]$row.Result; ReasonCode = $(if (& $field $row 'ReasonCode') { [string](& $field $row 'ReasonCode') } else { $null }) })
        }
        foreach ($t in @(if ($testsByStep.ContainsKey($id)) { $testsByStep[$id] })) {
            $tid = [string]$t.Id
            if ($listed.Contains($tid)) { continue }
            if ((& $field $t 'InstanceSource') -and $parentsWithRows.Contains($tid)) { continue }
            $null = $listed.Add($tid)
            $row = if ($rowById.ContainsKey($tid)) { $rowById[$tid] } else { $null }
            $tests.Add([pscustomobject][ordered]@{
                    Id         = $tid
                    Result     = if ($row) { [string]$row.Result } else { 'NotRun' }
                    ReasonCode = if ($row) { $(if (& $field $row 'ReasonCode') { [string](& $field $row 'ReasonCode') } else { $null }) } else { 'NotInRun' }
                })
        }
        $sortedTests = @($tests | Sort-Object -Property @{ Expression = { ($_.Id -replace '\d+', { $_.Value.PadLeft(10, '0') }) } })

        # Not $measure: PowerShell names ignore case, and that is the -Measure parameter.
        $stepMeasure = if ($step.Measure) { & $measureOf $step } else { $null }
        $measureRead = $stepMeasure -and -not $stepMeasure.ReasonCode
        $measureUnread = $stepMeasure -and $stepMeasure.ReasonCode -and $stepMeasure.ReasonCode -notin 'MeasureOff', 'NotRead'

        $ran = @($sortedTests | Where-Object { $_.Result -ne 'NotRun' })
        $counted = @($ran | Where-Object { -not ($_.Result -eq 'Skipped' -and $_.ReasonCode -eq 'NotApplicable') })
        $conditions = @($step.OnlyWhen | ForEach-Object { & $conditionOf $_ })

        $state = $null; $reason = $null
        if ($conditions -contains 'False') { $state = 'NotApplicable'; $reason = 'ConditionNotMet' }
        elseif ($conditions -contains 'Unknown') { $state = 'Unknown'; $reason = 'ConditionUnknown' }
        elseif ($ran.Count -gt 0 -and $counted.Count -eq 0 -and -not $measureRead) { $state = 'NotApplicable'; $reason = 'TestsNotApplicable' }
        elseif (($counted | Where-Object { $_.Result -eq 'Failed' }) -or ($measureRead -and -not $stepMeasure.Met)) { $state = 'NotDone' }
        else {
            $unsure = @($counted | Where-Object { $_.Result -in 'Investigate', 'Error', 'Skipped' })
            if ($unsure.Count -gt 0 -or $measureUnread) {
                $state = 'Unknown'
                $reason = if ($unsure.Count -gt 0) { $(if ($unsure[0].ReasonCode) { $unsure[0].ReasonCode } else { $unsure[0].Result }) } else { $stepMeasure.ReasonCode }
            } elseif ($counted.Count -gt 0 -or $measureRead) { $state = 'Done' }
            else {
                $state = 'NotChecked'
                $reason = if ($sortedTests.Count -gt 0) { 'NotSelected' } elseif ($stepMeasure -and $stepMeasure.ReasonCode -eq 'MeasureOff') { 'MeasureOff' } elseif ($stepMeasure) { 'NotRead' } else { 'NoCheck' }
            }
        }
        $status[$id] = $state

        # A step's own value: the highest priority among its failed tests.
        $own = 0.0
        foreach ($row in @($rows | Where-Object { $_.Result -eq 'Failed' })) { $p = Get-MtTestPriority -InputObject $row; if ($p -gt $own) { $own = $p } }

        $records[$id] = [ordered]@{
            Step = $step; Status = $state; Reason = $reason; Tests = $sortedTests; Measure = $stepMeasure; Own = $own
        }
    }

    # Readiness.
    $notMet = { param($other) $status.ContainsKey($other) -and $status[$other] -in 'Unknown', 'NotChecked' }
    foreach ($id in $scope.Steps) {
        $r = $records[$id]
        $step = $r.Step
        $blockedBy = [System.Collections.Generic.List[string]]::new()
        $unconfirmed = [System.Collections.Generic.List[string]]::new()
        $addTo = { param($list, $other) if (-not $list.Contains($other)) { $list.Add($other) } }
        foreach ($other in @($step.Requires)) {
            if (-not $status.ContainsKey($other)) { continue }
            if ($status[$other] -eq 'NotDone') { & $addTo $blockedBy $other }
            elseif (& $notMet $other) { & $addTo $unconfirmed $other }
        }
        foreach ($group in @($step.RequiresOneOf)) {
            $members = @($group | Where-Object { $status.ContainsKey($_) -and $status[$_] -ne 'NotApplicable' })
            if ($members.Count -eq 0 -or ($members | Where-Object { $status[$_] -eq 'Done' })) { continue }
            $open = @($members | Where-Object { $status[$_] -ne 'NotDone' })
            if ($open.Count -eq 0) { foreach ($m in $members) { & $addTo $blockedBy $m } }
            else { foreach ($m in $open) { & $addTo $unconfirmed $m } }
        }
        foreach ($other in @($step.Conflicts)) {
            if (-not $status.ContainsKey($other)) { continue }
            if ($status[$other] -eq 'Done') { & $addTo $blockedBy $other }
            elseif (& $notMet $other) { & $addTo $unconfirmed $other }
        }
        $r.BlockedBy = $blockedBy.ToArray()
        $r.Unconfirmed = $unconfirmed.ToArray()
        $r.Readiness = if ($r.Status -notin 'NotDone', 'Unknown', 'NotChecked') { $null }
        elseif ($blockedBy.Count -gt 0) { 'Blocked' }
        elseif ($unconfirmed.Count -gt 0) { 'Unconfirmed' }
        else { 'Ready' }
    }

    # Order edges within the scope: a step comes after its prerequisites. Dependents are the reverse.
    $prerequisitesOf = @{}
    $dependentsOf = @{}
    foreach ($id in $scope.Steps) { $dependentsOf[$id] = [System.Collections.Generic.List[string]]::new() }
    foreach ($id in $scope.Steps) {
        $step = $catalogSteps[$id]
        $before = @(@($step.Requires) + @($step.RequiresOneOf | ForEach-Object { $_ }) + @($step.RecommendedFirst) | Where-Object { $_ -and $inScope.Contains($_) } | Select-Object -Unique)
        $prerequisitesOf[$id] = $before
        foreach ($p in $before) { if (-not $dependentsOf[$p].Contains($id)) { $dependentsOf[$p].Add($id) } }
    }

    # Value: own value plus the own values of the NotDone steps that depend on it, at any depth.
    $value = @{}
    foreach ($id in $scope.Steps) {
        $seen = [System.Collections.Generic.HashSet[string]]::new($ordinal)
        $queue = [System.Collections.Generic.Queue[string]]::new()
        foreach ($d in $dependentsOf[$id]) { $queue.Enqueue($d) }
        $unlock = 0.0
        while ($queue.Count -gt 0) {
            $d = $queue.Dequeue()
            if (-not $seen.Add($d)) { continue }
            if ($status[$d] -eq 'NotDone') { $unlock += $records[$d].Own }
            foreach ($next in $dependentsOf[$d]) { $queue.Enqueue($next) }
        }
        $value[$id] = $records[$id].Own + $unlock
    }

    # Rank: by group, then topologically within the group, then by value and ID.
    $groupOf = {
        param($id)
        $r = $records[$id]
        switch ($r.Readiness) { 'Ready' { 0 } 'Unconfirmed' { 1 } 'Blocked' { 2 } default { if ($r.Status -eq 'Done') { 3 } else { 4 } } }
    }
    $rank = 0
    foreach ($group in 0..4) {
        $members = [System.Collections.Generic.List[string]]::new()
        foreach ($id in $scope.Steps) { if ((& $groupOf $id) -eq $group) { $members.Add($id) } }
        $placed = [System.Collections.Generic.HashSet[string]]::new($ordinal)
        while ($placed.Count -lt $members.Count) {
            $available = @($members | Where-Object {
                    $candidate = $_
                    -not $placed.Contains($candidate) -and -not ($prerequisitesOf[$candidate] | Where-Object { $members.Contains($_) -and -not $placed.Contains($_) })
                })
            # A cycle (which the catalogue's checks rule out) must not loop: take what is left.
            if ($available.Count -eq 0) { $available = @($members | Where-Object { -not $placed.Contains($_) }) }
            $next = $available | Sort-Object -Property @{ Expression = { $value[$_] }; Descending = $true }, @{ Expression = { $_ } } | Select-Object -First 1
            $null = $placed.Add($next)
            $rank++
            $records[$next].Rank = $rank
        }
    }

    # Goals that have a step in scope.
    $goalsOf = @{}
    $goals = foreach ($goal in $Catalog.Goals) {
        $goalSteps = @($goal.Steps | Where-Object { $inScope.Contains($_) })
        if ($goalSteps.Count -eq 0) { continue }
        foreach ($id in $goalSteps) {
            if (-not $goalsOf.ContainsKey($id)) { $goalsOf[$id] = [System.Collections.Generic.List[string]]::new() }
            $goalsOf[$id].Add($goal.Id)
        }
        $applicable = @($goalSteps | Where-Object { $status[$_] -ne 'NotApplicable' })
        $done = @($applicable | Where-Object { $status[$_] -eq 'Done' }).Count
        [pscustomobject][ordered]@{
            Id         = $goal.Id
            Title      = $goal.Title
            Summary    = $goal.Summary
            Step       = $goal.Step
            Steps      = [string[]]$goalSteps
            Done       = $done
            Applicable = $applicable.Count
            Unknown    = @($applicable | Where-Object { $status[$_] -eq 'Unknown' }).Count
            NotChecked = @($applicable | Where-Object { $status[$_] -eq 'NotChecked' }).Count
            Status     = if ($applicable.Count -eq 0) { 'NotApplicable' } elseif ($done -eq $applicable.Count) { 'Done' } elseif ($done -eq 0) { 'NotStarted' } else { 'InProgress' }
        }
    }

    # Earlier: what an earlier run found for a step this run did not check.
    $lastKnownOf = {
        param($testId)
        if ($null -eq $LastKnown) { return $null }
        if ($LastKnown -is [System.Collections.IDictionary]) { if ($LastKnown.Contains($testId)) { return $LastKnown[$testId] } else { return $null } }
        $p = $LastKnown.PSObject.Properties[$testId]
        if ($p) { $p.Value } else { $null }
    }
    $earlierOf = {
        param($tests)
        $known = @(foreach ($t in $tests) { $k = & $lastKnownOf $t.Id; if ($k -and [string]$k.Result -and [string]$k.Result -ne 'NotRun') { $k } })
        if ($known.Count -eq 0) { return $null }
        $counted = @($known | Where-Object { [string]$_.Result -ne 'Skipped' -or [string](& $field $_ 'ReasonCode') -ne 'NotApplicable' })
        $state = if ($counted.Count -eq 0) { 'NotApplicable' }
        elseif ($counted | Where-Object { [string]$_.Result -eq 'Failed' }) { 'NotDone' }
        elseif ($counted | Where-Object { [string]$_.Result -in 'Investigate', 'Error', 'Skipped' }) { 'Unknown' }
        else { 'Done' }
        $newest = $known | Sort-Object -Property @{ Expression = { [string]$_.ExecutedAt } } -Descending | Select-Object -First 1
        [pscustomobject][ordered]@{ Status = $state; ExecutedAt = $newest.ExecutedAt; File = $newest.File }
    }

    $ranked = @($scope.Steps | Sort-Object -Property @{ Expression = { $records[$_].Rank } })
    $out = foreach ($id in $ranked) {
        $r = $records[$id]
        $step = $r.Step
        $unlocks = @($dependentsOf[$id] | Where-Object { $status[$_] -notin 'Done', 'NotApplicable' } | Sort-Object -Property @{ Expression = { $records[$_].Rank } })
        [pscustomobject][ordered]@{
            Id               = $id
            Title            = $step.Title
            Summary          = $step.Summary
            Product          = $step.Product
            Goals            = [string[]]@(if ($goalsOf.ContainsKey($id)) { $goalsOf[$id] })
            Status           = $r.Status
            Reason           = $r.Reason
            Readiness        = $r.Readiness
            BlockedBy        = [string[]]$r.BlockedBy
            Unconfirmed      = [string[]]$r.Unconfirmed
            Unlocks          = [string[]]$unlocks
            Rank             = $r.Rank
            Tests            = @($r.Tests)
            Earlier          = if ($r.Status -eq 'NotChecked') { & $earlierOf $r.Tests } else { $null }
            Measure          = $r.Measure
            Requires         = [string[]]@($step.Requires)
            RequiresOneOf    = @(foreach ($g in @($step.RequiresOneOf)) { , [string[]]@($g) })
            RecommendedFirst = [string[]]@($step.RecommendedFirst)
            Conflicts        = [string[]]@($step.Conflicts)
            OnlyWhen         = [string[]]@($step.OnlyWhen)
            Rollout          = [string[]]@($step.Rollout)
            Sources          = @($step.Sources)
        }
    }

    [pscustomobject]@{
        Steps = @($out)
        Goals = @($goals)
    }
}
