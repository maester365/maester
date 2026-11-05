function Get-MtStepScope {
    <#
    .SYNOPSIS
    Returns the steps of the defender's path that a run's result covers: its scope.

    .DESCRIPTION
    A step is in scope when a row that ran names it, or when it is a prerequisite, at any depth, of such a step
    (docs/proposals/defenders-path.md, section 7.2). A row ran when its Result is anything but NotRun. The steps
    that a step in scope declares in Conflicts are in scope too, without their own prerequisites, because a
    conflicting step that is Done blocks it. Step IDs that the catalogue does not have are left out.

    Returns an object with Named (the steps the rows that ran name, in the order of the rows) and Steps (every step
    in scope, in catalogue order). Both are empty when no row that ran names a step.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Result rows, with Result and Step.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $InputObject = @(),

        # The step catalogue. Defaults to the module's.
        [Parameter()] [object] $Catalog = (Get-MtStepCatalog)
    )

    $steps = $Catalog.Steps
    $named = [System.Collections.Generic.List[string]]::new()
    foreach ($row in $InputObject) {
        if ($null -eq $row -or [string]$row.Result -eq 'NotRun') { continue }
        $property = $row.PSObject.Properties['Step']
        if (-not $property) { continue }
        foreach ($id in @($property.Value | Where-Object { $_ })) {
            $key = ([string]$id).ToLowerInvariant()
            if ($steps.ContainsKey($key) -and -not $named.Contains($key)) { $named.Add($key) }
        }
    }

    $inScope = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($id in $named) { $null = $inScope.Add($id) }
    foreach ($id in @(Get-MtStepPrerequisite -Step $named.ToArray() -Catalog $Catalog)) { $null = $inScope.Add($id) }
    foreach ($id in @($inScope)) {
        foreach ($other in @($steps[$id].Conflicts | Where-Object { $_ -and $steps.ContainsKey($_) })) { $null = $inScope.Add($other) }
    }

    [pscustomobject]@{
        Named = $named.ToArray()
        Steps = [string[]]@($steps.Keys | Where-Object { $inScope.Contains($_) })
    }
}
