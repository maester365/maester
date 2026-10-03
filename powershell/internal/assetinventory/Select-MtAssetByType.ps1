function Select-MtAssetByType {
    <#
    .SYNOPSIS
    Filters consolidated asset records down to the types that count as an asset.

    .DESCRIPTION
    Applies the catalog from Get-MtAssetTypeDefinition:
    - Types listed under ExcludedTypes are dropped silently (known findings, not objects).
    - For systems listed under KnownTypes, any other type is dropped and summarized in a
      warning so it can be triaged and added to the catalog.
    - Records of any other system pass through unchanged.

    .EXAMPLE
    Select-MtAssetByType -Assets $inventory

    Returns the inventory without Entra recommendations, PIM alerts and unknown types.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        # Consolidated asset records to filter.
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [object[]] $Assets
    )

    if (-not $Assets) { return @() }

    $definition = Get-MtAssetTypeDefinition
    $kept = [System.Collections.Generic.List[object]]::new()
    $dropped = [System.Collections.Generic.List[object]]::new()

    foreach ($asset in $Assets) {
        $system = [string]$asset.System
        $type = [string]$asset.Type

        if ($definition.ExcludedTypes.ContainsKey($system) -and $definition.ExcludedTypes[$system] -contains $type) {
            Write-Verbose "Asset inventory: dropping excluded type $system/$type."
            continue
        }

        if ($definition.KnownTypes.ContainsKey($system) -and $definition.KnownTypes[$system] -notcontains $type) {
            $dropped.Add($asset)
            continue
        }

        $kept.Add($asset)
    }

    if ($dropped.Count -gt 0) {
        $summary = $dropped | Group-Object -Property { "$($_.System)/$($_.Type)" } |
            Sort-Object Name | ForEach-Object { "$($_.Name) ($($_.Count))" }
        Write-Warning ("Asset inventory: {0} record(s) of unknown type were dropped: {1}. Add the type to Get-MtAssetTypeDefinition (KnownTypes) to inventory it, or to ExcludedTypes if it is not an asset." -f $dropped.Count, ($summary -join ', '))
    }

    return , $kept.ToArray()
}
