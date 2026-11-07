function Get-MtZtaWorkshopPlan {
    <#
    .SYNOPSIS
    Builds the Zero Trust plan that the report's Zero Trust plan view shows, from the pack's workshop folder.

    .DESCRIPTION
    Reads the Microsoft Zero Trust Workshop files that build/zero-trust-workshop/Update-MtZtWorkshopData.ps1 writes
    into the pack's workshop folder (one per pillar, and icons.json), Maester's additions in workshop/maester.json
    and the pack's taxonomy.json, and returns one object in the shape the report reads
    (Schema 'maester.zero-trust-workshop/1'): the pillars, their functional areas and tasks, each task with the
    checks that measure it, and the icons the plan uses.

    Each task lists its checks in this order, each ID once:
    - Source 'microsoft': the assessment tests Microsoft maps to the task (ztw-task-mapping.json);
    - Source 'same-check': for each of those, the built-in Maester tests that taxonomy.json says check the same
      setting (AlsoCheckedBy), with Via naming the assessment test;
    - Source 'maester': the Maester tests that maester.json adds to the task.
    Tasks that maester.json adds are appended to their pillar with Origin 'maester'.

    It reads files only, so it can be tested on its own. Returns $null when the folder has no pillar files.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The pack's workshop folder.
        [Parameter(Mandatory)] [string] $WorkshopPath,

        # The pack's taxonomy.json, for AlsoCheckedBy. Optional.
        [Parameter()] [string] $TaxonomyPath
    )

    # Built-in Maester tests that check the same setting as an assessment test, by assessment test ID.
    $sameCheck = @{}
    $taxonomy = Read-MtZtaWorkshopFile -Path $TaxonomyPath
    foreach ($entry in @((Get-MtZtaWorkshopValue $taxonomy 'Tests').PSObject.Properties | Where-Object { $_ -and $_.MemberType -eq 'NoteProperty' })) {
        $also = @(Get-MtZtaWorkshopValue $entry.Value 'AlsoCheckedBy' | Where-Object { $_ } | ForEach-Object { [string]$_ })
        if ($also.Count -gt 0) { $sameCheck[$entry.Name] = $also }
    }

    $overlay = Read-MtZtaWorkshopFile -Path (Join-Path $WorkshopPath 'maester.json')
    $overlayTasks = Get-MtZtaWorkshopValue $overlay 'Tasks'
    $extraTasks = @(Get-MtZtaWorkshopValue $overlay 'ExtraTasks' | Where-Object { $_ })
    $allIcons = Get-MtZtaWorkshopValue (Read-MtZtaWorkshopFile -Path (Join-Path $WorkshopPath 'icons.json')) 'Icons'
    $iconNames = [System.Collections.Generic.List[string]]::new()

    $pillarOrder = @('identity', 'devices', 'data', 'network', 'infrastructure', 'security-operations', 'ai')
    $updated = $null
    $sourceUrl = $null
    $pillars = [System.Collections.Generic.List[object]]::new()
    foreach ($pillarId in $pillarOrder) {
        $pillar = Read-MtZtaWorkshopFile -Path (Join-Path $WorkshopPath "$pillarId.json")
        if (-not $pillar) { Write-Verbose "The workshop folder has no $pillarId.json."; continue }
        $source = Get-MtZtaWorkshopValue $pillar 'Source'
        $date = [string](Get-MtZtaWorkshopValue $source 'Updated')
        if ($date -and (-not $updated -or [string]::CompareOrdinal($date, $updated) -gt 0)) { $updated = $date }
        if (-not $sourceUrl) { $sourceUrl = Get-MtZtaWorkshopValue $source 'Url' }

        $areas = @(foreach ($area in @(Get-MtZtaWorkshopValue $pillar 'Areas' | Where-Object { $_ })) {
                $row = [ordered]@{ Id = [string]$area.Id }
                foreach ($name in 'Name', 'Description', 'Icon') { $row[$name] = Get-MtZtaWorkshopValue $area $name }
                foreach ($key in @($row.Keys)) { if ($null -eq $row[$key]) { $row.Remove($key) } }
                if ($row.Icon) { $iconNames.Add([string]$row.Icon) }
                [pscustomobject]$row
            })

        $tasks = [System.Collections.Generic.List[object]]::new()
        foreach ($task in @(Get-MtZtaWorkshopValue $pillar 'Tasks' | Where-Object { $_ })) {
            $checks = [System.Collections.Generic.List[object]]::new()
            $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $microsoft = @(Get-MtZtaWorkshopValue $task 'Checks' | Where-Object { $_ } | ForEach-Object { [string]$_ })
            foreach ($id in $microsoft) {
                if ($seen.Add($id)) { $checks.Add([pscustomobject][ordered]@{ Id = $id; Source = 'microsoft' }) }
            }
            foreach ($id in $microsoft) {
                foreach ($also in @($sameCheck[($id -replace '^ZTA\.', '')] | Where-Object { $_ })) {
                    if ($seen.Add($also)) { $checks.Add([pscustomobject][ordered]@{ Id = $also; Source = 'same-check'; Via = $id }) }
                }
            }
            $added = Get-MtZtaWorkshopValue $overlayTasks ([string]$task.Id)
            foreach ($id in @(Get-MtZtaWorkshopValue $added 'Tests' | Where-Object { $_ } | ForEach-Object { [string]$_ })) {
                if ($seen.Add($id)) { $checks.Add([pscustomobject][ordered]@{ Id = $id; Source = 'maester' }) }
            }
            $tasks.Add((ConvertTo-MtZtaWorkshopTask -Task $task -Origin 'workshop' -Checks $checks.ToArray() -Note (Get-MtZtaWorkshopValue $added 'Note')))
        }
        foreach ($task in ($extraTasks | Where-Object { [string](Get-MtZtaWorkshopValue $_ 'Pillar') -eq $pillarId })) {
            $checks = @(Get-MtZtaWorkshopValue $task 'Tests' | Where-Object { $_ } | Select-Object -Unique | ForEach-Object { [pscustomobject][ordered]@{ Id = [string]$_; Source = 'maester' } })
            $tasks.Add((ConvertTo-MtZtaWorkshopTask -Task $task -Origin 'maester' -Checks $checks -Note (Get-MtZtaWorkshopValue $task 'Note')))
        }
        foreach ($task in $tasks) { if ($task.PSObject.Properties['Icon']) { $iconNames.Add([string]$task.Icon) } }

        $pillars.Add([pscustomobject][ordered]@{
                Id    = $pillarId
                Name  = [string](Get-MtZtaWorkshopValue $pillar 'Name')
                Areas = $areas
                Tasks = $tasks.ToArray()
            })
    }
    if ($pillars.Count -eq 0) { return $null }

    # Only the icons the plan uses, in the order it first uses them.
    $icons = [ordered]@{}
    foreach ($name in $iconNames) {
        if ($icons.Contains($name)) { continue }
        $svg = Get-MtZtaWorkshopValue $allIcons $name
        if ($svg) { $icons[$name] = [string]$svg }
    }

    $source = [ordered]@{ Name = 'Microsoft Zero Trust Workshop'; Url = $sourceUrl; Updated = $updated }
    foreach ($key in @($source.Keys)) { if (-not $source[$key]) { $source.Remove($key) } }
    [pscustomobject][ordered]@{
        Schema  = 'maester.zero-trust-workshop/1'
        Source  = [pscustomobject]$source
        Pillars = $pillars.ToArray()
        Icons   = [pscustomobject]$icons
    }
}
