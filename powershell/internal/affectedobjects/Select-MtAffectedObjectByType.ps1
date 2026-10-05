function Select-MtAffectedObjectByType {
    <#
    .SYNOPSIS
    Filters consolidated object records down to the types that count as an affected object.

    .DESCRIPTION
    Applies the catalog from Get-MtAffectedObjectTypeDefinition:
    - Types listed under ExcludedTypes are dropped silently (known findings, not objects).
    - For systems listed under KnownTypes, any other type is dropped and summarized in a
      warning so it can be triaged and added to the catalog.
    - Records of any other system pass through unchanged.

    .EXAMPLE
    Select-MtAffectedObjectByType -Objects $inventory

    Returns the inventory without Entra recommendations, PIM alerts and unknown types.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        # Consolidated object records to filter.
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [object[]] $Objects
    )

    if (-not $Objects) { return @() }

    $definition = Get-MtAffectedObjectTypeDefinition
    $kept = [System.Collections.Generic.List[object]]::new()
    $dropped = [System.Collections.Generic.List[object]]::new()

    foreach ($affectedObject in $Objects) {
        $system = [string]$affectedObject.System
        $type = [string]$affectedObject.Type

        if ($definition.ExcludedTypes.ContainsKey($system) -and $definition.ExcludedTypes[$system] -contains $type) {
            Write-Verbose "Affected objects: dropping excluded type $system/$type."
            continue
        }

        if ($definition.KnownTypes.ContainsKey($system) -and $definition.KnownTypes[$system] -notcontains $type) {
            $dropped.Add($affectedObject)
            continue
        }

        $kept.Add($affectedObject)
    }

    if ($dropped.Count -gt 0) {
        $summary = $dropped | Group-Object -Property { "$($_.System)/$($_.Type)" } |
            Sort-Object Name | ForEach-Object { "$($_.Name) ($($_.Count))" }
        Write-Warning ("Affected objects: {0} record(s) of unknown type were dropped: {1}. Add the type to Get-MtAffectedObjectTypeDefinition (KnownTypes) to inventory it, or to ExcludedTypes if it is not an affected object." -f $dropped.Count, ($summary -join ', '))
    }

    return , $kept.ToArray()
}
