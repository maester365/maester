function Get-MtStepCatalog {
    <#
    .SYNOPSIS
    Returns the step catalogue of the defender's path (assets/steps), with the problems found in it. Cached for the
    session.

    .DESCRIPTION
    The catalogue (docs/proposals/defenders-path.md, section 4) is a folder of JSON files: goals.json holds the
    goals, and <product-key>.json the steps of one product. A step is one change an administrator makes or one
    state the tenant must reach. Tests name the steps they verify with the Step attribute; the catalogue holds how
    steps relate (Requires, RequiresOneOf, RecommendedFirst, Conflicts, OnlyWhen), how to switch each on (Rollout),
    the Microsoft Learn pages behind them (Sources) and, for a step that is a state of the tenant, the measure that
    decides whether it is done (Measure: the Key of a measure in the measure registry and a MinimumShare).

    Returns an object with:

    - Steps: a case-sensitive dictionary of step ID to step, in file and catalogue order. Each step has every field
      of the format, lists as arrays and missing fields as empty arrays or $null, plus File.
    - Goals: the goals in catalogue order. Each has Id, Title, Summary, Step and Steps: the goal's step and its
      prerequisites at any depth (through Requires, RequiresOneOf and RecommendedFirst), prerequisites first.
    - Problems: one message for each thing that is wrong, each starting with the file name. The build fails on
      any (Get-MtStepProblem); a run uses what is valid.

    -Path reads another folder, such as a fixture in the unit tests, and is not cached.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The catalogue folder. Defaults to the module's assets/steps.
        [Parameter()] [string] $Path
    )

    if (-not $Path -and $script:__MtStepCatalog) { return $script:__MtStepCatalog }
    $folder = if ($Path) { $Path } else { Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/steps' }

    $problems = [System.Collections.Generic.List[string]]::new()
    $steps = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $goals = [System.Collections.Generic.List[object]]::new()
    $stepPattern = '^[a-z0-9][a-z0-9-]*\.[a-z0-9][a-z0-9-]*$'
    $linePattern = '^[^\r\n]+$'
    $stepKeys = @('Id', 'Title', 'Summary', 'Requires', 'RequiresOneOf', 'RecommendedFirst', 'Conflicts', 'OnlyWhen', 'Rollout', 'Sources', 'Measure', 'Unchecked')
    $sourceKeys = @('Url', 'Mirror', 'Maintainer', 'Note', 'Reviewed')
    $goalKeys = @('Id', 'Title', 'Summary', 'Step')
    $taxonomy = Get-MtTaxonomy

    # A text field: one line, at most -Max characters. Returns the value, or $null after recording a problem.
    $checkText = {
        param($where, $name, $value, $max, [bool] $required)
        if ($null -eq $value -or ($value -is [string] -and $value -eq '')) {
            if ($required) { $problems.Add("${where}: $name is required.") }
            return $null
        }
        if ($value -isnot [string] -or $value -notmatch $linePattern) { $problems.Add("${where}: $name must be one line of text."); return $null }
        if ($value.Length -gt $max) { $problems.Add("${where}: $name is longer than $max characters.") }
        $value
    }
    # A list of step IDs. Returns the valid IDs.
    $checkIds = {
        param($where, $name, $value)
        if ($null -eq $value) { return , @() }
        $ids = @($value)
        if ($value -is [string]) { $problems.Add("${where}: $name must be a list of step IDs."); return , @() }
        $valid = [System.Collections.Generic.List[string]]::new()
        foreach ($id in $ids) {
            if ($id -isnot [string] -or $id -cnotmatch $stepPattern) { $problems.Add("${where}: $name has '$id', which is not a step ID (<product-key>.<name>)."); continue }
            if ($valid.Contains($id)) { $problems.Add("${where}: $name lists '$id' twice."); continue }
            $valid.Add($id)
        }
        , $valid.ToArray()
    }

    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        $problems.Add("$($folder): the step catalogue folder does not exist.")
    }
    $files = @(Get-ChildItem -LiteralPath $folder -Filter '*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'steps.schema.json' } | Sort-Object Name)

    foreach ($file in $files) {
        $name = $file.Name
        try {
            $content = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        } catch {
            $problems.Add("${name}: the file is not valid JSON: $($_.Exception.Message)")
            continue
        }
        if ($content -isnot [System.Collections.IDictionary]) { $problems.Add("${name}: the file must hold a JSON object."); continue }

        if ($name -eq 'goals.json') {
            foreach ($key in $content.Keys) { if ($key -notin '$schema', 'Goals') { $problems.Add("${name}: unknown key '$key'. goals.json holds only Goals.") } }
            foreach ($g in @($content['Goals'])) {
                if ($g -isnot [System.Collections.IDictionary]) { $problems.Add("${name}: every goal must be an object."); continue }
                foreach ($key in $g.Keys) { if ($key -cnotin $goalKeys) { $problems.Add("${name}: goal '$($g['Id'])' has the unknown key '$key'.") } }
                $id = $g['Id']
                if ($id -isnot [string] -or $id -cnotmatch '^[a-z0-9][a-z0-9-]*$') { $problems.Add("${name}: '$id' is not a goal ID (lowercase kebab-case)."); continue }
                if ($goals | Where-Object { $_.Id -eq $id }) { $problems.Add("${name}: the goal '$id' is listed twice."); continue }
                $where = "$name ($id)"
                $goal = [ordered]@{
                    Id      = $id
                    Title   = & $checkText $where 'Title' $g['Title'] 100 $true
                    Summary = & $checkText $where 'Summary' $g['Summary'] 200 $true
                    Step    = $null
                    Steps   = @()
                }
                if ($g['Step'] -isnot [string] -or $g['Step'] -cnotmatch $stepPattern) { $problems.Add("${where}: Step must name the step that achieves the goal.") }
                else { $goal.Step = $g['Step'] }
                $goals.Add([pscustomobject]$goal)
            }
            continue
        }

        $product = $content['Product']
        $fileProduct = [System.IO.Path]::GetFileNameWithoutExtension($name)
        foreach ($key in $content.Keys) { if ($key -notin '$schema', 'Product', 'Steps') { $problems.Add("${name}: unknown key '$key'. A step file holds Product and Steps.") } }
        if ($product -cne $fileProduct) { $problems.Add("${name}: Product is '$product'. A step file is named after its product, so it must be '$fileProduct'.") }
        if (-not $taxonomy.Lookup.Product.ContainsKey($fileProduct) -or $taxonomy.Lookup.Product[$fileProduct].Key -cne $fileProduct) {
            $problems.Add("${name}: '$fileProduct' is not a product key of the taxonomy registry.")
        }

        foreach ($s in @($content['Steps'])) {
            if ($s -isnot [System.Collections.IDictionary]) { $problems.Add("${name}: every step must be an object."); continue }
            $id = $s['Id']
            if ($id -isnot [string] -or $id -cnotmatch $stepPattern) { $problems.Add("${name}: '$id' is not a step ID (<product-key>.<name>, lowercase)."); continue }
            if ($id.Length -gt 80) { $problems.Add("${name}: the step ID '$id' is longer than 80 characters.") }
            if (-not $id.StartsWith("$fileProduct.", [System.StringComparison]::Ordinal)) { $problems.Add("${name}: the step '$id' must start with '$fileProduct.', the product of its file.") }
            if ($steps.ContainsKey($id)) { $problems.Add("${name}: the step '$id' is also in $($steps[$id].File)."); continue }
            $where = "$name ($id)"
            foreach ($key in $s.Keys) { if ($key -cnotin $stepKeys) { $problems.Add("${where}: unknown key '$key'.") } }

            $oneOf = [System.Collections.Generic.List[object]]::new()
            if ($null -ne $s['RequiresOneOf']) {
                foreach ($group in @($s['RequiresOneOf'])) {
                    $members = & $checkIds $where 'RequiresOneOf' $group
                    if ($group -is [string] -or $members.Count -lt 2) { $problems.Add("${where}: each RequiresOneOf group lists at least two steps."); continue }
                    $oneOf.Add($members)
                }
            }
            $onlyWhen = [System.Collections.Generic.List[string]]::new()
            foreach ($condition in @($s['OnlyWhen'] | Where-Object { $null -ne $_ })) {
                if ($condition -is [string] -and ($condition -ceq 'hybrid-identity' -or $condition -cmatch '^license:[A-Za-z0-9_\-]+(&[A-Za-z0-9_\-]+)*$')) { $onlyWhen.Add($condition) }
                else { $problems.Add("${where}: OnlyWhen has '$condition', which is not a known condition (hybrid-identity, license:<service plan>).") }
            }
            $rollout = @(foreach ($sentence in @($s['Rollout'] | Where-Object { $null -ne $_ })) { & $checkText $where 'Rollout' $sentence 200 $true })

            $sources = [System.Collections.Generic.List[object]]::new()
            foreach ($src in @($s['Sources'] | Where-Object { $null -ne $_ })) {
                if ($src -isnot [System.Collections.IDictionary]) { $problems.Add("${where}: every source must be an object."); continue }
                foreach ($key in $src.Keys) { if ($key -cnotin $sourceKeys) { $problems.Add("${where}: a source has the unknown key '$key'.") } }
                $url = $src['Url']; $maintainer = $src['Maintainer']
                if ([bool]$url -eq [bool]$maintainer) { $problems.Add("${where}: a source has either a Url or a Maintainer."); }
                if ($url -and ($url -isnot [string] -or $url -notmatch '^https://learn\.microsoft\.com/\S+$')) { $problems.Add("${where}: the source '$url' is not a Microsoft Learn URL.") }
                elseif ($url -and $url -match '^https://learn\.microsoft\.com/[a-z]{2}-[a-z]{2}/') { $problems.Add("${where}: the source '$url' has a locale. Leave it out, as the check guides do.") }
                if ($maintainer -and ($maintainer -isnot [string] -or $maintainer -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$')) { $problems.Add("${where}: the source maintainer '$maintainer' is not a GitHub handle.") }
                if ($src['Mirror'] -and ($src['Mirror'] -isnot [string] -or $src['Mirror'] -notmatch '^[a-z0-9-]+-docs-mirror$')) { $problems.Add("${where}: the source mirror '$($src['Mirror'])' is not the name of a docs mirror repository.") }
                $reviewed = $src['Reviewed']
                if ($reviewed -is [datetime]) { $reviewed = $reviewed.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture) }
                $date = [datetime]::MinValue
                if ($reviewed -isnot [string] -or -not [datetime]::TryParseExact($reviewed, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref] $date)) {
                    $problems.Add("${where}: a source needs Reviewed, the date it was last read against the step (yyyy-MM-dd).")
                }
                $sources.Add([pscustomobject][ordered]@{
                        Url        = if ($url) { [string]$url } else { $null }
                        Mirror     = if ($src['Mirror']) { [string]$src['Mirror'] } else { $null }
                        Maintainer = if ($maintainer) { [string]$maintainer } else { $null }
                        Note       = & $checkText $where 'A source''s Note' $src['Note'] 200 $true
                        Reviewed   = $reviewed
                    })
            }
            if ($sources.Count -eq 0) { $problems.Add("${where}: a step needs at least one source.") }

            # Measure: the figure that decides whether a state step is done. Whether its Key is in the measure
            # registry is checked by Get-MtStepProblem.
            $measure = $null
            if ($null -ne $s['Measure']) {
                $m = $s['Measure']
                if ($m -isnot [System.Collections.IDictionary]) {
                    $problems.Add("${where}: Measure must be an object with Key and MinimumShare.")
                } else {
                    foreach ($key in $m.Keys) { if ($key -cnotin 'Key', 'MinimumShare') { $problems.Add("${where}: Measure has the unknown key '$key'.") } }
                    $measureKey = $m['Key']
                    $minimum = $m['MinimumShare']
                    $validKey = $measureKey -is [string] -and $measureKey -cmatch '^[a-z0-9][a-z0-9-]*$'
                    $validMinimum = ($minimum -is [int] -or $minimum -is [long]) -and $minimum -ge 1 -and $minimum -le 100
                    if (-not $validKey) { $problems.Add("${where}: Measure's Key '$measureKey' is not a measure key (lowercase kebab-case).") }
                    if (-not $validMinimum) { $problems.Add("${where}: Measure's MinimumShare must be a whole number from 1 to 100.") }
                    if ($validKey -and $validMinimum) { $measure = [pscustomobject][ordered]@{ Key = $measureKey; MinimumShare = [int]$minimum } }
                }
                if ($s['Unchecked']) { $problems.Add("${where}: the step has a Measure, so it must not have Unchecked.") }
            }

            $steps[$id] = [pscustomobject][ordered]@{
                Id               = $id
                Product          = $fileProduct
                Title            = & $checkText $where 'Title' $s['Title'] 100 $true
                Summary          = & $checkText $where 'Summary' $s['Summary'] 200 $true
                Requires         = & $checkIds $where 'Requires' $s['Requires']
                RequiresOneOf    = $oneOf.ToArray()
                RecommendedFirst = & $checkIds $where 'RecommendedFirst' $s['RecommendedFirst']
                Conflicts        = & $checkIds $where 'Conflicts' $s['Conflicts']
                OnlyWhen         = $onlyWhen.ToArray()
                Rollout          = $rollout
                Sources          = $sources.ToArray()
                Measure          = $measure
                Unchecked        = & $checkText $where 'Unchecked' $s['Unchecked'] 200 $false
                File             = $name
            }
        }
    }

    # References: every step a relationship names exists, no step names itself, and none names a step in two
    # relationships.
    $edges = @{}
    foreach ($step in $steps.Values) {
        $where = "$($step.File) ($($step.Id))"
        $named = @{}
        $relations = [ordered]@{
            Requires         = @($step.Requires)
            RequiresOneOf    = @($step.RequiresOneOf | ForEach-Object { $_ })
            RecommendedFirst = @($step.RecommendedFirst)
            Conflicts        = @($step.Conflicts)
        }
        foreach ($relation in $relations.Keys) {
            foreach ($other in ($relations[$relation] | Select-Object -Unique)) {
                if ($other -ceq $step.Id) { $problems.Add("${where}: $relation names the step itself."); continue }
                if (-not $steps.ContainsKey($other)) { $problems.Add("${where}: $relation names '$other', which is not in the catalogue."); continue }
                if ($named.ContainsKey($other) -and $named[$other] -ne $relation) { $problems.Add("${where}: '$other' is in both $($named[$other]) and $relation.") }
                $named[$other] = $relation
            }
        }
        # Order edges: the step comes after these.
        $edges[$step.Id] = @(@($relations.Requires) + @($relations.RequiresOneOf) + @($relations.RecommendedFirst) | Where-Object { $_ -cne $step.Id -and $steps.ContainsKey($_) } | Select-Object -Unique)
    }

    # Cycles through Requires, RequiresOneOf and RecommendedFirst. Each cycle is reported once, from its first step
    # in catalogue order.
    $state = @{}
    $reported = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $visit = $null
    $visit = {
        param($id, [System.Collections.Generic.List[string]] $trail)
        $state[$id] = 'Visiting'
        $trail.Add($id)
        foreach ($next in $edges[$id]) {
            if ($state[$next] -eq 'Visiting') {
                $cycle = @($trail.GetRange($trail.IndexOf($next), $trail.Count - $trail.IndexOf($next))) + $next
                $key = (@($cycle | Select-Object -SkipLast 1 | Sort-Object) -join ' ')
                if ($reported.Add($key)) { $problems.Add("$($steps[$next].File) ($next): the steps depend on each other in a cycle: $($cycle -join ' -> ').") }
            } elseif (-not $state[$next]) {
                & $visit $next $trail
            }
        }
        $trail.RemoveAt($trail.Count - 1)
        $state[$id] = 'Done'
    }
    foreach ($id in @($steps.Keys)) { if (-not $state[$id]) { & $visit $id ([System.Collections.Generic.List[string]]::new()) } }

    # A goal's steps: its step and every prerequisite at any depth, prerequisites first. The walk stops at a step
    # it has seen, so a cycle (already reported) does not loop.
    $inGoal = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($goal in $goals) {
        if (-not $goal.Step) { continue }
        if (-not $steps.ContainsKey($goal.Step)) { $problems.Add("goals.json ($($goal.Id)): Step names '$($goal.Step)', which is not in the catalogue."); continue }
        $order = [System.Collections.Generic.List[string]]::new()
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $walk = $null
        $walk = {
            param($id)
            if (-not $seen.Add($id)) { return }
            foreach ($next in $edges[$id]) { & $walk $next }
            $order.Add($id)
        }
        & $walk $goal.Step
        $goal.Steps = $order.ToArray()
        foreach ($id in $order) { $null = $inGoal.Add($id) }
    }
    foreach ($step in $steps.Values) {
        if (-not $inGoal.Contains($step.Id)) { $problems.Add("$($step.File) ($($step.Id)): the step belongs to no goal. Make it a goal's step or a prerequisite of one.") }
    }
    if ($files.Count -gt 0 -and -not ($files | Where-Object Name -EQ 'goals.json')) { $problems.Add("goals.json: the catalogue has no goals file.") }

    $catalog = [pscustomobject]@{
        Path     = $folder
        Steps    = $steps
        Goals    = $goals.ToArray()
        Problems = $problems.ToArray()
    }
    if (-not $Path) { $script:__MtStepCatalog = $catalog }
    $catalog
}
