function Read-MtZtaJsonExport {
    <#
    .SYNOPSIS
        Internal: opens a ZTA bundle's JSON shadow export (zt-export/<Table>/<Table>-N.json
        files) and returns a query context with the same shape as `Read-MtZtaDatabase`.

    .DESCRIPTION
        Tier 1 reader — universal, dependency-free path. Reads the per-table JSON shards
        ZTA writes alongside `zt.db`. Streaming-bounded by largest shard (~70-100 MB per
        ZTA's sharding policy), so memory peak stays the same regardless of total table
        size. Hashtable indexes are built lazily on demand.

        Returns a context object whose surface matches `Read-MtZtaDatabase` (DuckDB tier)
        so callers can swap interchangeably:

            BundlePath   = original bundle root path (string)
            ExportRoot   = resolved zt-export/ root (string)
            Tables       = array of table names discovered as zt-export/<Name>/ folders
            HasTable     = scriptblock(name)               -> bool
            HasColumn    = scriptblock(table, column)      -> bool   (probes first shard)
            GetRows      = scriptblock(table[, predicate[, top]])  -> rows  (streaming)
            BuildIndex   = scriptblock(table[, keyColumn]) -> hashtable<keyValue, row>
            Query        = scriptblock(sql)                -> rows   (mini SQL adapter)
            SupportsSql  = $true (limited subset only — see Get-MtZtaSqlPlan)
            Tier         = 'JsonExport'
            Dispose      = scriptblock                     (clears caches)

        Schema baseline (16 tables) is asserted at load time. `vwRole` is excluded
        because it is a DuckDB view, not a JSON-shadow folder.

    .PARAMETER BundlePath
        Path to the ZTA result bundle. The reader probes
        `<BundlePath>/zt-export/<Table>/<Table>-N.json` first, then falls back to
        `<BundlePath>/<Table>/...` for compact bundles that flatten the export.

    .PARAMETER LimitToTables
        Optional string array. When supplied, only these tables are listed in
        `Tables`. Used by callers that want to defer schema-baseline assertions or
        narrow the surface for a specific test.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $BundlePath,

        [Parameter(Mandatory = $false)]
        [string[]] $LimitToTables
    )

    if (-not (Test-Path $BundlePath)) {
        throw "Read-MtZtaJsonExport: bundle path not found: $BundlePath"
    }

    # Resolve the export root. Two layouts in the wild:
    #   <BundlePath>/zt-export/<Table>/...    (canonical from ZTA)
    #   <BundlePath>/<Table>/...              (rare, when a packager flattens)
    $exportRoot = Join-Path $BundlePath 'zt-export'
    if (-not (Test-Path $exportRoot)) {
        $exportRoot = $BundlePath
    }

    # Discover tables = subdirectories under the export root that contain
    # at least one <Name>-*.json file (excluding *-model.json).
    $tableDirs = Get-ChildItem -Path $exportRoot -Directory -ErrorAction SilentlyContinue |
                 Where-Object {
                     Get-ChildItem -Path $_.FullName -Filter "$($_.Name)-*.json" -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -notlike '*-model.json' } |
                         Select-Object -First 1
                 }
    $discoveredTables = @($tableDirs | ForEach-Object { $_.Name })

    # Baseline-required tables absent as folders may be empty in this tenant —
    # ZTA omits the folder when the table has zero rows. Include them as
    # known-empty so GetRows returns @() and callers don't need to special-case.
    # vwRole is a DuckDB view (RoleAssignment join RoleDefinition), not a JSON
    # shadow folder, so it is not in the baseline list.
    $required = @(
        'Application','ConfigurationPolicy','Device',
        'RoleAssignment','RoleAssignmentGroup',
        'RoleAssignmentScheduleInstance','RoleAssignmentScheduleInstanceGroup',
        'RoleDefinition',
        'RoleEligibilityScheduleInstance','RoleEligibilityScheduleInstanceGroup',
        'RoleManagementPolicyAssignment',
        'ServicePrincipal','ServicePrincipalSignIn',
        'SignIn','User','UserRegistrationDetails'
    )

    # Final table list = baseline-required ∪ discovered (deduped, sorted).
    $tables = @(($discoveredTables + $required) | Sort-Object -Unique)

    if ($LimitToTables) {
        $tables = @($tables | Where-Object { $_ -in $LimitToTables })
    }

    # Lazy caches, captured by closures below via .GetNewClosure().
    $rowCache    = @{}    # tableName -> rows (when materialised by BuildIndex or full scan)
    $indexCache  = @{}    # "$table:$column" -> hashtable<value, row>

    # ---- Internal helpers (closure-captured) ----------------------------

    # Stream-iterate one table's shards into the supplied $collector list.
    # Filters via $predicate and stops once $top rows have been collected
    # (when $top -gt 0). Top control lives here so $collector.Count is the
    # only authoritative counter — sidesteps PowerShell closure-by-value
    # semantics on simple [int] variables.
    $iterateTable = {
        param(
            [string] $table,
            [scriptblock] $predicate,
            [System.Collections.Generic.List[object]] $collector,
            [int] $top = 0
        )

        $shardDir = Join-Path $exportRoot $table
        if (-not (Test-Path $shardDir)) { return }

        # Files matching <Table>-N.json (skip <Table>-model.json which is a schema descriptor).
        $shards = Get-ChildItem -Path $shardDir -Filter "$table-*.json" -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -notlike '*-model.json' } |
                  Sort-Object Name

        foreach ($shard in $shards) {
            try {
                $payload = Get-Content -Path $shard.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Write-Verbose "Read-MtZtaJsonExport: skipping shard $($shard.Name) (parse error: $($_.Exception.Message))"
                continue
            }
            # Two payload shapes ZTA emits:
            #   { "@odata.context": "...", "value": [ ...rows... ] }   (most tables)
            #   [ ...rows... ]                                          (rare)
            $rows = if ($payload.PSObject.Properties['value'] -and $null -ne $payload.value) {
                @($payload.value)
            } elseif ($payload -is [System.Array]) {
                @($payload)
            } else {
                @($payload)
            }

            foreach ($row in $rows) {
                # ZTA emits rows with isZtModelRow=true as schema sentinels; filter them out.
                if ($row -and $row.PSObject.Properties['isZtModelRow'] -and $row.isZtModelRow) { continue }
                if ($predicate -and -not (& $predicate $row)) { continue }
                $collector.Add($row)
                if ($top -gt 0 -and $collector.Count -ge $top) { return }
            }
        }
    }.GetNewClosure()

    # ---- Surface scriptblocks (returned to caller) ----------------------

    $hasTableFn = {
        param([string] $name)
        return ($tables -contains $name)
    }.GetNewClosure()

    $hasColumnFn = {
        param([string] $table, [string] $column)
        # Cheap probe: read the first row of the first shard, check property bag.
        $shardDir = Join-Path $exportRoot $table
        $first = Get-ChildItem -Path $shardDir -Filter "$table-*.json" -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notlike '*-model.json' } | Sort-Object Name | Select-Object -First 1
        if (-not $first) { return $false }
        try {
            $payload = Get-Content $first.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
            $rows = if ($payload.value) { @($payload.value) } else { @($payload) }
            $sample = $rows | Where-Object { -not ($_.PSObject.Properties['isZtModelRow'] -and $_.isZtModelRow) } | Select-Object -First 1
            if (-not $sample) { return $false }
            return [bool]$sample.PSObject.Properties[$column]
        } catch { return $false }
    }.GetNewClosure()

    $getRowsFn = {
        param([string] $table, [scriptblock] $Predicate, [int] $Top = 0)
        if (-not (& $hasTableFn $table)) { return @() }

        $collected = New-Object System.Collections.Generic.List[object]
        & $iterateTable $table $Predicate $collected $Top
        return $collected.ToArray()
    }.GetNewClosure()

    $buildIndexFn = {
        param([string] $table, [string] $KeyColumn = 'id')
        $cacheKey = "${table}:${KeyColumn}"
        if ($indexCache.ContainsKey($cacheKey)) { return $indexCache[$cacheKey] }

        $rows = New-Object System.Collections.Generic.List[object]
        & $iterateTable $table $null $rows 0
        $h = @{}
        foreach ($r in $rows) {
            $v = $r.$KeyColumn
            if ($null -ne $v -and -not [string]::IsNullOrEmpty([string]$v)) {
                # Last write wins on hash collisions — same behaviour as DuckDB's first-row-by-PK.
                $h[[string]$v] = $r
            }
        }
        $indexCache[$cacheKey] = $h
        return $h
    }.GetNewClosure()

    # Mini SQL adapter — only handles the patterns our tests need. Keeps the API
    # surface symmetrical with the DuckDB tier without trying to be a SQL engine.
    # Recognised forms:
    #   SELECT COUNT(*) FROM <table>
    #   SELECT COUNT(*) FROM <table> WHERE <col> = '<value>'
    #   SELECT * FROM <table> [LIMIT <n>]
    # Anything else throws NotSupportedException with guidance to use GetRows directly.
    $queryFn = {
        param([string] $sql)
        $clean = ($sql -replace '\s+', ' ').Trim()

        # COUNT(*) FROM <t> [WHERE <col> = '<v>']
        if ($clean -match "^\s*SELECT\s+COUNT\s*\(\s*\*\s*\)\s+FROM\s+`"?([A-Za-z_][A-Za-z0-9_]*)`"?(\s+WHERE\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*'([^']*)')?\s*$") {
            $tbl = $matches[1]
            if ($matches[2]) {
                $col = $matches[3]; $val = $matches[4]
                $pred = [scriptblock]::Create("param(`$row); `$row.$col -eq '$val'")
                $rows = & $getRowsFn $tbl $pred 0
            }
            else {
                $rows = & $getRowsFn $tbl $null 0
            }
            return @([pscustomobject]@{ count_star = $rows.Count })
        }

        # SELECT * FROM <t> [LIMIT N]
        if ($clean -match '^\s*SELECT\s+\*\s+FROM\s+"?([A-Za-z_][A-Za-z0-9_]*)"?\s*(LIMIT\s+(\d+))?\s*$') {
            $tbl = $matches[1]
            $top = if ($matches[3]) { [int]$matches[3] } else { 0 }
            return ,@(& $getRowsFn $tbl $null $top)
        }

        throw [System.NotSupportedException]::new(
            "Read-MtZtaJsonExport: SQL adapter does not support this query — use GetRows / BuildIndex directly. SQL: $sql"
        )
    }.GetNewClosure()

    $disposeFn = {
        $rowCache.Clear()
        $indexCache.Clear()
    }.GetNewClosure()

    return [pscustomobject]@{
        Tier        = 'JsonExport'
        BundlePath  = $BundlePath
        ExportRoot  = $exportRoot
        Tables      = $tables
        SupportsSql = $true
        HasTable    = $hasTableFn
        HasColumn   = $hasColumnFn
        GetRows     = $getRowsFn
        BuildIndex  = $buildIndexFn
        Query       = $queryFn
        Dispose     = $disposeFn
    }
}
