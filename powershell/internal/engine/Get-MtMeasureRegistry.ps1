function Get-MtMeasureRegistry {
    <#
    .SYNOPSIS
    Returns the measure registry of the defender's path (assets/MaesterMeasures.psd1), with the problems found in
    it. Cached for the session.

    .DESCRIPTION
    A measure is a figure the engine reads from Graph for a step that is a state of the tenant
    (docs/proposals/defenders-path.md, section 11). Steps name a measure by its Key in the step catalogue.

    Returns an object with Measures, a case-sensitive dictionary of key to entry (Key, Function, Title, Unit, Caveat,
    Service, License, Permission, each list as an array, Caveat empty when the entry has none), and Problems, one
    message for each entry that is wrong. Whether the reader function exists is checked by Get-MtStepProblem, which
    runs in the module.

    -Path reads another file, such as a fixture in the unit tests, and is not cached.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The registry file. Defaults to the module's assets/MaesterMeasures.psd1.
        [Parameter()] [string] $Path
    )

    if (-not $Path -and $script:__MtMeasureRegistry) { return $script:__MtMeasureRegistry }
    $file = if ($Path) { $Path } else { Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterMeasures.psd1' }
    $name = [System.IO.Path]::GetFileName($file)

    $problems = [System.Collections.Generic.List[string]]::new()
    $measures = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $schema = Get-MtTestSchema
    $services = Get-MtServiceRegistry
    $keys = @('Key', 'Function', 'Title', 'Unit', 'Caveat', 'Service', 'License', 'Permission')

    $data = $null
    try { $data = Import-PowerShellDataFile -LiteralPath $file -ErrorAction Stop }
    catch { $problems.Add("${name}: the file can't be read: $($_.Exception.Message)") }

    foreach ($entry in @($data.Measures | Where-Object { $null -ne $_ })) {
        if ($entry -isnot [hashtable]) { $problems.Add("${name}: every measure must be a hashtable."); continue }
        $key = $entry['Key']
        if ($key -isnot [string] -or $key -cnotmatch '^[a-z0-9][a-z0-9-]*$') { $problems.Add("${name}: '$key' is not a measure key (lowercase kebab-case)."); continue }
        if ($measures.ContainsKey($key)) { $problems.Add("${name}: the measure '$key' is listed twice."); continue }
        $where = "$name ($key)"
        foreach ($k in $entry.Keys) { if ($k -cnotin $keys) { $problems.Add("${where}: unknown key '$k'.") } }
        if ($entry['Function'] -isnot [string] -or $entry['Function'] -cnotmatch '^[A-Z][a-z]+-Mt[A-Za-z0-9]+$') { $problems.Add("${where}: Function must name a Maester function, Verb-MtNoun.") }
        foreach ($text in 'Title', 'Unit') {
            if ($entry[$text] -isnot [string] -or $entry[$text] -notmatch '^[^\r\n]+$') { $problems.Add("${where}: $text must be one line of text.") }
        }
        if ($entry.ContainsKey('Caveat') -and ($entry['Caveat'] -isnot [string] -or $entry['Caveat'] -notmatch '^[^\r\n]{1,200}$')) {
            $problems.Add("${where}: Caveat must be one line of 200 characters or less.")
        }
        $service = @($entry['Service'] | Where-Object { $_ })
        if ($service.Count -eq 0) { $problems.Add("${where}: Service is required.") }
        foreach ($s in $service) {
            if (-not (Resolve-MtServiceName -Name ([string]$s) -Registry $services)) { $problems.Add("${where}: Service '$s' is not in the service registry.") }
        }
        foreach ($l in @($entry['License'] | Where-Object { $_ })) {
            if ([string]$l -notmatch $schema.Properties.License.Pattern) { $problems.Add("${where}: License '$l' is not valid.") }
        }
        foreach ($p in @($entry['Permission'] | Where-Object { $_ })) {
            if ([string]$p -notmatch $schema.Properties.Permission.Pattern) { $problems.Add("${where}: Permission '$p' is not valid. Write <Service>:<Kind>:<Name>.") }
        }
        $measures[$key] = [pscustomobject][ordered]@{
            Key        = $key
            Function   = [string]$entry['Function']
            Title      = [string]$entry['Title']
            Unit       = [string]$entry['Unit']
            Caveat     = if ($entry['Caveat'] -is [string]) { $entry['Caveat'] } else { '' }
            Service    = [string[]]@($service)
            License    = [string[]]@($entry['License'] | Where-Object { $_ })
            Permission = [string[]]@($entry['Permission'] | Where-Object { $_ })
        }
    }

    $registry = [pscustomobject]@{
        Path     = $file
        Measures = $measures
        Problems = $problems.ToArray()
    }
    if (-not $Path) { $script:__MtMeasureRegistry = $registry }
    $registry
}
