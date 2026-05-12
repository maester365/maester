function Read-MtZtaDatabase {
    <#
    .SYNOPSIS
        Internal: opens a ZTA `zt.db` (DuckDB) read-only and returns a query callable plus
        schema introspection helpers.

    .DESCRIPTION
        DuckDB-first reader for `Import-MtZtaResult`. Opens with read-only access mode so
        multiple processes can share the same `zt.db` concurrently.

        Schema baseline — 17 tables present in every observed tenant:
            Application, ConfigurationPolicy, Device,
            RoleAssignment, RoleAssignmentGroup,
            RoleAssignmentScheduleInstance, RoleAssignmentScheduleInstanceGroup,
            RoleDefinition,
            RoleEligibilityScheduleInstance, RoleEligibilityScheduleInstanceGroup,
            RoleManagementPolicyAssignment,
            ServicePrincipal, ServicePrincipalSignIn,
            SignIn, User, UserRegistrationDetails,
            vwRole

        Net-additive per-tenant columns are limited to Microsoft Graph metadata markers
        (`@odata.type`, `@odata.context`) and are lazy-probed by callers via `HasColumn`.

        Returns a context object whose surface matches `Read-MtZtaJsonExport`
        (Tier 1) so callers can swap interchangeably:

            [pscustomobject] {
                Tier        = 'Database'
                Connection  = [System.Data.IDbConnection]
                Query       = [scriptblock]      # { param($sql) ... } -> [array of rows]
                Tables      = [string[]]         # tables observed in 'main' schema
                SupportsSql = $true
                HasTable    = [scriptblock]      # ($name) -> [bool]
                HasColumn   = [scriptblock]      # ($table, $column) -> [bool]
                GetRows     = [scriptblock]      # ($table, $pred, $top) -> [rows]
                BuildIndex  = [scriptblock]      # ($table, $keyColumn) -> hashtable
                Dispose     = [scriptblock]      # closes the connection cleanly
            }

        Throws on failure (missing native binary, unreadable .db, schema baseline check
        finds required tables absent). Caller (Import-MtZtaResult) catches and falls
        back to JSON-only mode with a one-line warning.

    .PARAMETER DatabasePath
        Path to the zt.db file. Must exist.

    .PARAMETER ModuleRoot
        Module root path (defaults to `$PSScriptRoot/..`). Used to locate `lib/DuckDB.NET.Data.dll`
        when the assemblies aren't already loaded into the AppDomain.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $DatabasePath,

        [Parameter(Mandatory = $false)]
        [string] $ModuleRoot
    )

    if (-not (Test-Path $DatabasePath)) {
        throw "Read-MtZtaDatabase: database file not found: $DatabasePath"
    }

    if (-not $ModuleRoot) {
        $ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot '..') | Select-Object -ExpandProperty Path
    }

    # Opportunistic: returns $null on miss rather than throwing so callers can
    # treat DuckDB as an accelerator. The JSON-shadow reader is the universal floor.
    $assembliesReady = Initialize-MtZtaDuckDbAssembly -ModuleRoot $ModuleRoot
    if (-not $assembliesReady) {
        Write-Verbose "Read-MtZtaDatabase: DuckDB tier unavailable; caller should fall back to Read-MtZtaJsonExport (Tier 1)."
        return $null
    }

    # READ_ONLY mode lets multiple processes share the same file safely.
    $absPath = (Resolve-Path $DatabasePath).Path
    $connStr = "Data Source=$absPath;ACCESS_MODE=READ_ONLY"

    $conn = [DuckDB.NET.Data.DuckDBConnection]::new($connStr)
    try {
        $conn.Open()
    }
    catch {
        $conn.Dispose()
        throw "Read-MtZtaDatabase: failed to open DuckDB at '$absPath' read-only ($($_.Exception.Message)). DB version mismatch or file lock?"
    }

    # .GetNewClosure() captures $conn from the current scope — $using: is PSRemoting
    # syntax and does not apply here.
    $queryFn = {
        param([string] $sql)
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $sql
        $reader = $cmd.ExecuteReader()
        $rows = @()
        try {
            while ($reader.Read()) {
                $row = [ordered]@{}
                for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                    $row[$reader.GetName($i)] = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
                }
                $rows += [pscustomobject]$row
            }
        }
        finally {
            $reader.Dispose()
            $cmd.Dispose()
        }
        return ,$rows
    }.GetNewClosure()

    $tables = @()
    try {
        $tableRows = & $queryFn "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
        $tables = @($tableRows | ForEach-Object { $_.table_name })
    }
    catch {
        $conn.Close(); $conn.Dispose()
        throw "Read-MtZtaDatabase: schema probe failed ($($_.Exception.Message)). information_schema.tables is unreadable."
    }

    # Baseline assertion — all required tables must exist.
    $required = @(
        'Application','ConfigurationPolicy','Device',
        'RoleAssignment','RoleAssignmentGroup',
        'RoleAssignmentScheduleInstance','RoleAssignmentScheduleInstanceGroup',
        'RoleDefinition',
        'RoleEligibilityScheduleInstance','RoleEligibilityScheduleInstanceGroup',
        'RoleManagementPolicyAssignment',
        'ServicePrincipal','ServicePrincipalSignIn',
        'SignIn','User','UserRegistrationDetails','vwRole'
    )
    $missing = $required | Where-Object { $_ -notin $tables }
    if ($missing) {
        $conn.Close(); $conn.Dispose()
        throw "Read-MtZtaDatabase: schema baseline mismatch. Missing tables: $($missing -join ', '). Database may be from a ZTA version older than 2.2.0."
    }

    $hasTableFn = {
        param([string] $name)
        return ($tables -contains $name)
    }.GetNewClosure()

    $hasColumnFn = {
        param([string] $tableName, [string] $columnName)
        $rows = & $queryFn "SELECT column_name FROM information_schema.columns WHERE table_schema='main' AND table_name='$tableName' AND column_name='$columnName' LIMIT 1"
        return ($rows.Count -gt 0)
    }.GetNewClosure()

    # GetRows / BuildIndex match the JsonExport surface so callers can swap readers
    # interchangeably. Predicate and top are applied in PowerShell after SELECT *.
    # Table names are quoted because `User` is a SQL reserved word in DuckDB.
    $getRowsFn = {
        param([string] $table, [scriptblock] $Predicate, [int] $Top = 0)
        if (-not ($tables -contains $table)) { return @() }
        $rows = & $queryFn ('SELECT * FROM "' + $table + '"')
        if (-not $Predicate -and $Top -le 0) { return $rows }
        $collected = New-Object System.Collections.Generic.List[object]
        foreach ($r in $rows) {
            if ($Predicate -and -not (& $Predicate $r)) { continue }
            $collected.Add($r)
            if ($Top -gt 0 -and $collected.Count -ge $Top) { break }
        }
        return $collected.ToArray()
    }.GetNewClosure()

    $buildIndexFn = {
        param([string] $table, [string] $KeyColumn = 'id')
        if (-not ($tables -contains $table)) { return @{} }
        $rows = & $queryFn ('SELECT * FROM "' + $table + '"')
        $h = @{}
        foreach ($r in $rows) {
            $v = $r.$KeyColumn
            if ($null -ne $v -and -not [string]::IsNullOrEmpty([string]$v)) {
                $h[[string]$v] = $r
            }
        }
        return $h
    }.GetNewClosure()

    $disposeFn = {
        # DuckDB sometimes throws on Close()/Dispose() when the underlying file handle
        # is already gone (e.g. after a forced Pester scope teardown). Swallow silently.
        try { $conn.Close() }   catch { Write-Verbose "Read-MtZtaDatabase: Close() during dispose: $($_.Exception.Message)" }
        try { $conn.Dispose() } catch { Write-Verbose "Read-MtZtaDatabase: Dispose() during dispose: $($_.Exception.Message)" }
    }.GetNewClosure()

    return [pscustomobject]@{
        Tier        = 'Database'
        Connection  = $conn
        Query       = $queryFn
        Tables      = $tables
        SupportsSql = $true
        HasTable    = $hasTableFn
        HasColumn   = $hasColumnFn
        GetRows     = $getRowsFn
        BuildIndex  = $buildIndexFn
        Dispose     = $disposeFn
    }
}

function Initialize-MtZtaDuckDbAssembly {
    <#
    .SYNOPSIS
        Internal: opportunistically locates DuckDB.NET.Data (and its native libduckdb)
        and loads them into the AppDomain. Returns $true on success, $false on miss.

    .DESCRIPTION
        Best-effort: returns $true on success, $false on miss (never throws).
        Maester ships zero DuckDB binaries; the JSON-shadow reader covers all callers.
        Probes in order:

        1. AppDomain — already loaded (the ZeroTrustAssessment module declares
           DuckDB.NET.Data as a RequiredAssembly, so importing ZTA auto-loads it).
        2. ZeroTrustAssessment module's `lib/` folder — preferred path; ZTA ships
           matching versioned binaries.
        3. Maester's own `lib/` folder — backward-compatible path for operators
           who manually populated it.

        On any miss returns $false. Caller (Read-MtZtaDatabase) translates that
        into a $null return so callers treat DuckDB as an opportunistic accelerator.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ModuleRoot
    )

    # Probe 1: already in AppDomain (ZTA already loaded into the session)
    if ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'DuckDB.NET.Data' }) {
        Write-Verbose "Initialize-MtZtaDuckDbAssembly: DuckDB.NET.Data already loaded into AppDomain."
        return $true
    }

    # Probe 2: ZeroTrustAssessment module's lib/ — preferred path (versioned with ZTA)
    $ztaMod = Get-Module ZeroTrustAssessment -ErrorAction SilentlyContinue
    if (-not $ztaMod) {
        $ztaMod = Get-Module -ListAvailable ZeroTrustAssessment -ErrorAction SilentlyContinue |
                  Sort-Object Version -Descending | Select-Object -First 1
    }
    if ($ztaMod) {
        $ztaManaged = Join-Path $ztaMod.ModuleBase 'lib/DuckDB.NET.Data.dll'
        if (Test-Path $ztaManaged) {
            try {
                Add-Type -Path $ztaManaged -ErrorAction Stop
                Write-Verbose "Initialize-MtZtaDuckDbAssembly: loaded $ztaManaged (from ZeroTrustAssessment v$($ztaMod.Version))."
                return $true
            }
            catch {
                Write-Verbose "Initialize-MtZtaDuckDbAssembly: Add-Type failed on ZTA's $ztaManaged ($($_.Exception.Message)). Falling through."
            }
        }
    }

    # Probe 3: Maester's own lib/ — legacy operator-populated path
    $managed = Join-Path $ModuleRoot 'lib/DuckDB.NET.Data.dll'
    if (Test-Path $managed) {
        try {
            Add-Type -Path $managed -ErrorAction Stop
            Write-Verbose "Initialize-MtZtaDuckDbAssembly: loaded $managed (from Maester's own lib/)."
            return $true
        }
        catch {
            Write-Verbose "Initialize-MtZtaDuckDbAssembly: Add-Type failed on Maester's $managed ($($_.Exception.Message))."
        }
    }

    Write-Verbose 'Initialize-MtZtaDuckDbAssembly: no DuckDB.NET.Data assembly available — Tier 1 (JSON shadow) will carry the load.'
    return $false
}
