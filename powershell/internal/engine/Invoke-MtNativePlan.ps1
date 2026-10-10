function Invoke-MtNativePlan {
    <#
    .SYNOPSIS
    Runs the native tests of a plan through the engine and returns one result row per test or instance.

    .DESCRIPTION
    Stage 7 and 8 for native tests (design section 5.1). Custom test files are loaded into private
    modules, families are expanded through their InstanceSource, every test runs through the C#
    scheduler (Invoke-MtEngineRun) on the caller's runspace, and each outcome is turned into a result
    row with the 2.x fields plus the 3.0 fields (ConvertTo-MtNativeRow). Rows for tests that did not
    run are produced from the plan.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Rows from Resolve-MtNativePlan.
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Plan,
        [Parameter(Mandatory)] [pscustomobject] $RunConfig,
        [Parameter()] [AllowNull()] [pscustomobject] $Selection,
        # None, Normal, Detailed or Diagnostic (design section 5.4).
        [Parameter()] [string] $Verbosity = 'None'
    )

    $maester = $ExecutionContext.SessionState.Module
    if (-not $__MtSession.NativeTestInfo) { $__MtSession.NativeTestInfo = @{} }
    if (-not $__MtSession.NativeReturnValue) { $__MtSession.NativeReturnValue = @{} }
    $rows = [System.Collections.Generic.List[object]]::new()
    $workItems = [System.Collections.Generic.List[object]]::new()

    # Custom files: one private module per file.
    $modules = @{}
    foreach ($fileGroup in ($Plan | Where-Object { $_.Disposition -eq 'Run' -and -not $_.Test.BuiltIn } | Group-Object { $_.Test.File })) {
        try {
            $modules[$fileGroup.Name] = Import-MtCustomTestFile -Path $fileGroup.Name
        } catch {
            foreach ($p in $fileGroup.Group) {
                $p.Disposition = 'Error'; $p.ReasonCode = 'LoadFailed'
                $p.ReasonDetail = "The file could not be loaded: $($_.Exception.Message)"
            }
        }
    }

    foreach ($p in $Plan) {
        if ($p.Disposition -ne 'Run') { $rows.Add((ConvertTo-MtNativeRow -PlanRow $p)); continue }
        $module = if ($p.Test.BuiltIn) { $maester } else { $modules[$p.Test.File] }
        $markdown = Get-MtNativeTestMarkdown -Test $p.Test

        if (-not $p.Test.InstanceSource) {
            $__MtSession.NativeTestInfo[$p.Test.Id] = @{ FunctionName = $p.Test.FunctionName; Markdown = $markdown }
            Clear-MtNativeTestState -Id $p.Test.Id
            $workItems.Add((New-MtNativeWorkItem -PlanRow $p -Id $p.Test.Id -Module $module -Parameters $p.Parameters))
            continue
        }

        # A family: the instance source runs in the execute stage, never during discovery.
        $expansion = Expand-MtTestFamily -PlanRow $p -Module $module -RunConfig $RunConfig -Selection $Selection
        foreach ($r in $expansion.Rows) { $rows.Add($r) }
        foreach ($instance in $expansion.Instances) {
            $instanceId = "$($p.Test.Id).$($instance.Id)"
            $__MtSession.NativeTestInfo[$instanceId] = @{ FunctionName = $p.Test.FunctionName; Markdown = $markdown }
            Clear-MtNativeTestState -Id $instanceId
            $parameters = @{} + $p.Parameters
            $parameters['Instance'] = $instance
            $workItems.Add((New-MtNativeWorkItem -PlanRow $p -Id $instanceId -Module $module -Parameters $parameters -Instance $instance))
        }
    }

    if ($workItems.Count -gt 0) {
        # Console output (design section 5.4 and docs/proposals/maester-3.0-console-output.md): an interactive
        # run draws the live status region; Stream and Plain write lines, with a heartbeat and log groups in CI.
        $console = if ($__MtSession.Console) { $__MtSession.Console } else { Get-MtConsoleMode }
        # Invoke-Maester creates the renderer of an interactive run; a run started another way gets its own.
        $renderer = $null
        $ownRenderer = $false
        if ($console.Mode -eq 'Interactive') {
            $renderer = $script:__MtConsoleRenderer
            if (-not $renderer) { $renderer = New-MtConsoleRenderer -Console $console; $ownRenderer = $true }
        }
        $ci = if ($console.Mode -ne 'Interactive') { $console.CI } else { $null }
        $heartbeat = @{ Done = 0; Failed = 0; Total = $workItems.Count; Clock = [System.Diagnostics.Stopwatch]::StartNew(); Last = [System.Diagnostics.Stopwatch]::StartNew() }

        $writeStartLines = $Verbosity -in 'Detailed', 'Diagnostic'
        $writeResultLines = $Verbosity -ne 'None'

        # Rows are made as each test finishes, so the live counts use the same result as the report.
        $converted = @{}
        $starting = {
            param($item)
            if (-not $renderer -and $writeStartLines) { Write-MtConsoleLine (Format-MtConsoleText "Running $($item.Id)" -Style Dim -Console $console) }
        }
        $finished = {
            param($result)
            $foreignWarning = $null
            $foreign = Remove-MtForeignModule -WarningAction SilentlyContinue -WarningVariable foreignWarning
            if ($foreignWarning) {
                if ($renderer) { $renderer.Pause() }
                try { foreach ($w in $foreignWarning) { Write-Warning $w.Message } } finally { if ($renderer) { $renderer.Resume() } }
            }
            $row = ConvertTo-MtNativeRow -PlanRow $result.Tag.PlanRow -RunResult $result -Instance $result.Tag.Instance -ForeignModuleLoaded:$foreign
            $converted[$result] = $row
            if ($renderer) { $renderer.ItemFinished([string]$row.Result) }
            if ($writeResultLines) { Write-MtNativeResultLine -Row $row -Console $console }
            $heartbeat.Done++
            if ($row.Result -in 'Failed', 'Error') { $heartbeat.Failed++ }
            if ($ci -and $heartbeat.Done -lt $heartbeat.Total -and ($heartbeat.Done % 50 -eq 0 -or $heartbeat.Last.Elapsed.TotalSeconds -ge 10)) {
                Write-MtRunHeartbeat -Done $heartbeat.Done -Total $heartbeat.Total -Failed $heartbeat.Failed -Elapsed $heartbeat.Clock.Elapsed -Console $console
                $heartbeat.Last.Restart()
            }
        }

        if ($ci) { Write-MtCIGroup -Name "Maester: $($workItems.Count) native tests" -Console $console }
        try {
            if ($renderer) { $renderer.Start($workItems.Count) }
            $results = @(Invoke-MtEngineRun -WorkItem $workItems.ToArray() -Module $maester -OnItemStarting $starting -OnItemFinished $finished -Renderer $renderer)
        } finally {
            if ($renderer) {
                $renderer.Stop()
                if ($ownRenderer) { $script:__MtConsoleRenderer = $null }
            }
            if ($ci) { Write-MtCIGroup -End -Console $console }
        }
        foreach ($result in $results) {
            # Items the run never started (Ctrl+C) get a result but no OnItemFinished call.
            $row = if ($converted.ContainsKey($result)) { $converted[$result] } else { ConvertTo-MtNativeRow -PlanRow $result.Tag.PlanRow -RunResult $result -Instance $result.Tag.Instance }
            $rows.Add($row)
        }
    }
    $rows.ToArray()
}

function Clear-MtNativeTestState {
    <#
    .SYNOPSIS
    Forgets the result detail and return value an earlier run left for a test, so they cannot leak into this run.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Clears in-memory session state only.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Id
    )
    if ($__MtSession.TestResultDetail -and $__MtSession.TestResultDetail.ContainsKey($Id)) { $null = $__MtSession.TestResultDetail.Remove($Id) }
    if ($__MtSession.NativeReturnValue -and $__MtSession.NativeReturnValue.ContainsKey($Id)) { $null = $__MtSession.NativeReturnValue.Remove($Id) }
}

function New-MtNativeWorkItem {
    <#
    .SYNOPSIS
    Creates the engine work item for one native test or family instance.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only.')]
    [CmdletBinding()]
    [OutputType([Maester.Engine.MtWorkItem])]
    param(
        [Parameter(Mandatory)] [object] $PlanRow,
        [Parameter(Mandatory)] [string] $Id,
        [Parameter()] [AllowNull()] [psmoduleinfo] $Module,
        [Parameter()] [hashtable] $Parameters = @{},
        [Parameter()] [AllowNull()] [object] $Instance
    )
    $item = [Maester.Engine.MtWorkItem]::new()
    $item.Id = $Id
    $item.Command = $PlanRow.Test.FunctionName
    $item.Title = if ($Instance -and $Instance.PSObject.Properties['Title'] -and $Instance.Title) { [string]$Instance.Title } else { [string]$PlanRow.Test.Title }
    $item.Parameters = $Parameters
    $item.Module = $Module
    $item.Lane = 'Main'
    $item.Exclusive = [bool]$PlanRow.Test.Exclusive
    if ($PlanRow.TimeoutSeconds -gt 0) { $item.TimeoutSeconds = $PlanRow.TimeoutSeconds }
    $item.Tag = @{ PlanRow = $PlanRow; Instance = $Instance }
    $item
}

function Expand-MtTestFamily {
    <#
    .SYNOPSIS
    Calls a family's InstanceSource and returns the instances to run and the rows for those that do not.

    .DESCRIPTION
    The source returns one object per instance: Id (the suffix; required, unique,
    ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$) and optional Title, Severity, Tag and Data (design section 10).
    A source that throws gives one Error row on the parent ID (InstanceSourceFailed); no instances give
    one Skipped row (NoInstances); an invalid or repeated suffix gives one Error row (InvalidInstanceId).
    Instances that an instance-level ID pattern, -ExcludeTestId or a disabled TestSettings row deselects
    get NotRun rows on their instance IDs.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $PlanRow,
        [Parameter()] [AllowNull()] [psmoduleinfo] $Module,
        [Parameter(Mandatory)] [pscustomobject] $RunConfig,
        [Parameter()] [AllowNull()] [pscustomobject] $Selection
    )

    $test = $PlanRow.Test
    $parentRow = {
        param($disposition, $code, $detail)
        $copy = [pscustomobject]@{} ; foreach ($prop in $PlanRow.PSObject.Properties) { $copy | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value }
        $copy.Disposition = $disposition; $copy.ReasonCode = $code; $copy.ReasonDetail = $detail
        ConvertTo-MtNativeRow -PlanRow $copy
    }

    # The source runs as the parent test, so Add-MtTestResultDetail -SkippedBecause in it skips the family
    # (for example when the feature the family enumerates is not enabled in the tenant).
    try {
        $previousTest = [Maester.Engine.MtSession]::EnterTest($test.Id)
        $raw = if ($Module) { & $Module { param($fn) & $fn } $test.InstanceSource } else { & $test.InstanceSource }
        $instances = @($raw | Where-Object { $null -ne $_ })
    } catch {
        if ($_.FullyQualifiedErrorId -like "$([Maester.Engine.MtSession]::SkipErrorId)*") {
            return [pscustomobject]@{ Instances = @(); Rows = @(& $parentRow 'Skipped' 'TestSkipped' $_.Exception.Message) }
        }
        return [pscustomobject]@{ Instances = @(); Rows = @(& $parentRow 'Error' 'InstanceSourceFailed' "The instance source $($test.InstanceSource) failed: $($_.Exception.Message)") }
    } finally {
        [Maester.Engine.MtSession]::ExitTest($previousTest)
    }
    if ($instances.Count -eq 0) {
        return [pscustomobject]@{ Instances = @(); Rows = @(& $parentRow 'Skipped' 'NoInstances' 'There is nothing in this tenant for this test to check.') }
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($i in $instances) {
        $suffix = [string]$i.Id
        if ($suffix -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$' -or -not $seen.Add($suffix)) {
            return [pscustomobject]@{ Instances = @(); Rows = @(& $parentRow 'Error' 'InvalidInstanceId' "The instance source returned an invalid or repeated instance ID '$suffix'.") }
        }
    }

    $run = [System.Collections.Generic.List[object]]::new()
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($i in $instances) {
        $instanceId = "$($test.Id).$($i.Id)"
        $reason = $null
        if (@($PlanRow.InstancePatterns).Count -gt 0 -and -not (Test-MtIdMatch -Id $instanceId -Pattern $PlanRow.InstancePatterns)) {
            $reason = @('NotSelected', 'Not in the list of test IDs to run.')
        } elseif ($Selection -and (Test-MtIdMatch -Id $instanceId -Pattern $Selection.ExcludeTestId)) {
            $reason = @('ExcludedById', "Excluded by ID.")
        } else {
            $setting = Get-MtTestSetting -RunConfig $RunConfig -Id $instanceId
            if ($setting -and $setting.PSObject.Properties['Enabled'] -and $setting.Enabled -eq $false) {
                $reason = @('DisabledByConfig', $(if ($setting.PSObject.Properties['Reason'] -and $setting.Reason) { [string]$setting.Reason } else { 'Disabled in the Maester config.' }))
            }
        }
        if ($reason) {
            $copy = [pscustomobject]@{}; foreach ($prop in $PlanRow.PSObject.Properties) { $copy | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value }
            $copy.Disposition = 'NotRun'; $copy.ReasonCode = $reason[0]; $copy.ReasonDetail = $reason[1]
            $rows.Add((ConvertTo-MtNativeRow -PlanRow $copy -Instance $i))
        } else {
            $run.Add($i)
        }
    }
    [pscustomobject]@{ Instances = $run.ToArray(); Rows = $rows.ToArray() }
}

function Get-MtNativeTestMarkdown {
    <#
    .SYNOPSIS
    Returns the Description and Result template of a native test from its .md file or the module's bundle.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $Test
    )

    $content = $null
    if ($Test.MarkdownPath -and (Test-Path -LiteralPath $Test.MarkdownPath)) {
        $content = Get-Content -LiteralPath $Test.MarkdownPath -Raw
    } elseif ($Test.Id) {
        if ($null -eq $script:__MtNativeMarkdownBundle) {
            $bundleFile = Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'Maester.TestMetadata.json'
            $script:__MtNativeMarkdownBundle = if (Test-Path -LiteralPath $bundleFile) { Get-Content -LiteralPath $bundleFile -Raw | ConvertFrom-Json } else { $false }
        }
        if ($script:__MtNativeMarkdownBundle -and $script:__MtNativeMarkdownBundle.PSObject.Properties[$Test.Id]) {
            $entry = $script:__MtNativeMarkdownBundle.($Test.Id)
            return [pscustomobject]@{ Description = $entry.Description; Result = $entry.Result }
        }
    }
    if (-not $content) { return $null }
    $parts = $content -split '<!--- Results --->', 2
    [pscustomobject]@{ Description = $parts[0]; Result = if ($parts.Count -gt 1) { $parts[1] } else { $null } }
}

function ConvertTo-MtNativeRow {
    <#
    .SYNOPSIS
    Builds the result row of a native test from its plan row and, when it ran, the engine's result.

    .DESCRIPTION
    Applies the test contract (design section 5.2), in this order: -SkippedBecause Error; -Investigate;
    any other skip; an uncaught error; the returned value. The row has every 2.x field (Index is set
    later) and the 3.0 fields Source, Suite, Format, ReasonCode, ReasonDetail, ParentId, InstanceId,
    Parameters and Diagnostics.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $PlanRow,
        [Parameter()] [AllowNull()] [object] $RunResult,
        [Parameter()] [AllowNull()] [object] $Instance,
        [Parameter()] [switch] $ForeignModuleLoaded
    )

    $test = $PlanRow.Test
    $isInstance = $null -ne $Instance
    $id = if ($isInstance) { "$($test.Id).$($Instance.Id)" } else { $test.Id }
    $markdown = Get-MtNativeTestMarkdown -Test $test
    $detail = if ($RunResult -and $__MtSession.TestResultDetail.ContainsKey($id)) { $__MtSession.TestResultDetail[$id] } else { $null }

    # Title: the instance's, else the helper's -TestTitle for a family instance, else the attribute's.
    $title = $test.Title
    if ($isInstance) {
        if ($Instance.PSObject.Properties['Title'] -and $Instance.Title) { $title = [string]$Instance.Title }
        elseif ($detail -and $detail.TestTitle) { $title = [string]$detail.TestTitle -replace "^$([regex]::Escape($id)):\s*", '' }
    }

    # Severity: config row (instance, then parent), the instance's, the attribute's, then the helper's.
    $setting = if ($__MtSession.MaesterConfig) { Get-MtTestSetting -RunConfig $__MtSession.MaesterConfig -Id $id -ParentId $(if ($isInstance) { $test.Id } else { $null }) } else { $null }
    $severity = if ($setting -and $setting.PSObject.Properties['Severity'] -and $setting.Severity) { [string]$setting.Severity }
    elseif ($isInstance -and $Instance.PSObject.Properties['Severity'] -and $Instance.Severity) { [string]$Instance.Severity }
    elseif ($test.Severity) { [string]$test.Severity }
    elseif ($detail -and $detail.Severity) { [string]$detail.Severity }
    else { '' }

    $tags = @($test.EffectiveTag)
    if ($isInstance -and $Instance.PSObject.Properties['Tag'] -and $Instance.Tag) { $tags = @($tags + @($Instance.Tag) | Select-Object -Unique) }

    $result = $PlanRow.Disposition
    $reasonCode = $PlanRow.ReasonCode
    $reasonDetail = $PlanRow.ReasonDetail
    $errorRecords = @()
    $diagnostics = @()
    $duration = [timespan]::Zero

    if ($RunResult) {
        $duration = $RunResult.Duration
        $diagnostics = @(@($RunResult.Warnings | ForEach-Object { "WARNING: $($_.Message)" }) + @($RunResult.Errors | ForEach-Object { "ERROR: $($_.Exception.Message)" }))
        $status = [string]$RunResult.Status
        $kind = [string]$RunResult.ReturnKind
        $skipCode = if ($detail) { [string]$detail.TestSkipped } else { $null }
        if ($RunResult.TerminatingError) { $errorRecords = @($RunResult.TerminatingError) }

        if ($ForeignModuleLoaded) {
            $result = 'Error'; $reasonCode = 'ForeignModuleLoaded'
            $reasonDetail = 'Another version of Maester was loaded while this test ran, so its result cannot be trusted.'
        } elseif ($skipCode -eq 'Error') {
            $result = 'Error'; $reasonCode = 'TestError'; $reasonDetail = Get-MtFirstLine $detail.SkippedReason
        } elseif ($detail -and $detail.TestInvestigate) {
            $result = 'Investigate'; $reasonCode = $null; $reasonDetail = $null
        } elseif ($status -eq 'Skipped' -or $skipCode) {
            $result = 'Skipped'
            $reasonCode = if ($skipCode -eq 'NotApplicable') { 'NotApplicable' } else { 'TestSkipped' }
            $reasonDetail = if ($detail) { [string]$detail.SkippedReason } else { $RunResult.Reason }
        } elseif ($status -eq 'Error') {
            $result = 'Error'
            $reasonCode = if ($RunResult.IsParameterBindingError) { 'InvalidConfiguration' } else { 'TestError' }
            $reasonDetail = $RunResult.Reason
        } elseif ($status -in 'Aborted', 'Cancelled', 'NotRun') {
            $result = 'Error'; $reasonCode = 'TestError'; $reasonDetail = $RunResult.Reason
        } elseif ($status -eq 'Timeout') {
            $result = 'Error'; $reasonCode = 'Timeout'; $reasonDetail = $RunResult.Reason
        } else {
            switch ($kind) {
                'True' { $result = 'Passed'; $reasonCode = $null; $reasonDetail = $null }
                'False' { $result = 'Failed'; $reasonCode = $null; $reasonDetail = $null }
                'Null' {
                    $result = 'Skipped'; $reasonCode = 'NoResult'
                    $reasonDetail = if ($test.PSObject.Properties['NoResultReason'] -and $test.NoResultReason) { $test.NoResultReason } else { 'The test returned no result.' }
                }
                default {
                    $result = 'Error'; $reasonCode = 'InvalidReturn'
                    $reasonDetail = if ($kind -eq 'Multiple') { 'The test returned more than one value; it must return $true or $false.' } else { "The test returned $($RunResult.ReturnValue.GetType().Name); it must return `$true or `$false." }
                }
            }
        }
        $__MtSession.NativeReturnValue[$id] = $kind
    }

    # Rows the engine produced without a recorded detail still carry the 2.x text fields.
    if (-not $detail) {
        $description = if ($markdown) { $markdown.Description } else { 'This test was not run.' }
        $detail = switch ($result) {
            'NotRun' { @{ TestTitle = $null; TestDescription = $description; TestResult = 'This test was not run.'; TestSkipped = $null; SkippedReason = $null; TestInvestigate = $false; Severity = $null; Service = $null } }
            'Skipped' { @{ TestTitle = $null; TestDescription = $description; TestResult = "Skipped. $reasonDetail"; TestSkipped = $PlanRow.LegacySkipCode; SkippedReason = $reasonDetail; TestInvestigate = $false; Severity = $null; Service = $null } }
            'Error' {
                $errorText = if ($RunResult -and $RunResult.TerminatingError) { ($RunResult.TerminatingError | Out-String).Trim() } else { $reasonDetail }
                $reason = "An error occurred while running the test. ⚠️`n`n" + '```' + "`n`n$errorText`n`n" + '```' + "`n`n"
                @{ TestTitle = $null; TestDescription = $description; TestResult = "Error. $reason"; TestSkipped = $null; SkippedReason = $reason; TestInvestigate = $false; Severity = $null; Service = $null }
            }
            default { $null }
        }
    }
    if ($detail -is [hashtable]) { $detail = [pscustomobject]$detail }

    $file = if ($test.BuiltIn -and $test.File) { ConvertTo-MtRepositoryPath -Path $test.File } else { $test.File }

    [pscustomobject][ordered]@{
        Index           = 0
        Id              = $id
        Title           = $title
        Name            = "${id}: $title"
        HelpUrl         = $test.HelpUrl
        Severity        = $severity
        Tag             = $tags
        Result          = $result
        ScriptBlock     = ''
        ScriptBlockFile = $file
        ErrorRecord     = $errorRecords
        Block           = $test.Category
        Duration        = $duration.ToString('hh\:mm\:ss\.fff')
        ResultDetail    = $detail
        Source          = $test.Source
        Suite           = $test.Suite
        Format          = 'Native'
        ReasonCode      = $reasonCode
        ReasonDetail    = $reasonDetail
        ParentId        = if ($isInstance -or $test.InstanceSource) { $test.Id } else { $null }
        InstanceId      = if ($isInstance) { $id } else { $null }
        Parameters      = @($PlanRow.EffectiveParameters)
        Diagnostics     = $diagnostics
    }
}

function ConvertTo-MtRepositoryPath {
    <#
    .SYNOPSIS
    Returns a built-in test's path relative to the repository (tests/...), as results record it.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Path)
    if (-not [System.IO.Path]::IsPathRooted($Path)) { return $Path -replace '\\', '/' }
    $root = [System.IO.Path]::GetFullPath((Get-MtMaesterTestFolderPath)).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    if ($Path.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return 'tests/' + ($Path.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/')
    }
    $Path
}

function Get-MtFirstLine {
    <#
    .SYNOPSIS
    Returns the first meaningful line of a message (skipping the generic error preamble and code fences).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter()] [AllowNull()] [AllowEmptyString()] [string] $Text)
    if (-not $Text) { return $null }
    $lines = $Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne '```' -and $_ -notlike 'An error occurred while running the test*' }
    $lines | Select-Object -First 1
}

function Write-MtNativeResultLine {
    <#
    .SYNOPSIS
    Writes the one-line console result of a finished native test (design section 5.4).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Row,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    if (-not $Console) { $Console = Get-MtConsoleMode }
    $style = switch ($Row.Result) { 'Passed' { 'Passed' } 'Failed' { 'Failed' } 'Error' { 'Error' } 'Investigate' { 'Investigate' } default { 'Dim' } }
    $label = Format-MtResultLabel -Result $Row.Result -Console $Console
    $duration = try { Format-MtDuration ([timespan]::Parse($Row.Duration, [cultureinfo]::InvariantCulture)) } catch { $Row.Duration }
    $line = "$(Format-MtConsoleText $label -Style $style -Console $Console) $($Row.Id): $($Row.Title) $(Format-MtConsoleText "($duration)" -Style Dim -Console $Console)"
    if ($Row.Result -in 'Failed', 'Error' -and $Row.ReasonDetail) { $line += " - $(Get-MtFirstLine $Row.ReasonDetail)" }
    Write-MtConsoleLine $line
}
