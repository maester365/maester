function Get-MtStepPrerequisite {
    <#
    .SYNOPSIS
    Returns the prerequisites of steps of the defender's path, at any depth.

    .DESCRIPTION
    A prerequisite is a step that another step requires, requires one of, or recommends first
    (docs/proposals/defenders-path.md, section 3). This follows those three relationships down every level from
    -Step and returns each step it reaches once, in the order it reaches them. A step of -Step is returned only when
    another step of -Step reaches it. Step IDs the catalogue does not have are ignored.

    Used by -IncludePrerequisites (section 8) and by the scope of a result's Steps (section 7.2).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The steps whose prerequisites are wanted.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [string[]] $Step = @(),

        # The step catalogue. Defaults to the module's.
        [Parameter()] [object] $Catalog = (Get-MtStepCatalog)
    )

    $steps = $Catalog.Steps
    $start = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($id in @($Step | Where-Object { $_ })) { $null = $start.Add(([string]$id).ToLowerInvariant()) }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($id in $start) { if ($steps.ContainsKey($id)) { $queue.Enqueue($id) } }
    $reached = [System.Collections.Generic.List[string]]::new()
    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    while ($queue.Count -gt 0) {
        $id = $queue.Dequeue()
        if (-not $visited.Add($id)) { continue }
        $s = $steps[$id]
        $next = @(@($s.Requires) + @($s.RequiresOneOf | ForEach-Object { $_ }) + @($s.RecommendedFirst) | Where-Object { $_ })
        foreach ($other in $next) {
            if (-not $steps.ContainsKey($other)) { continue }
            if ($seen.Add($other)) { $reached.Add($other) }
            $queue.Enqueue($other)
        }
    }
    foreach ($id in $reached) { $id }
}
