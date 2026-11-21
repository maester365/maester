function Copy-MtADQueryResult {
    [CmdletBinding()]
    [OutputType([object], [object[]], [System.Collections.Specialized.OrderedDictionary], [pscustomobject])]
    param([AllowNull()] [object] $Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [byte[]]) { return ,([byte[]]$Value.Clone()) }
    if ($Value -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Value.Keys) { $copy[$key] = Copy-MtADQueryResult -Value $Value[$key] }
        return $copy
    }
    if ($Value -is [array]) {
        $copy = [object[]]::new($Value.Length)
        for ($i = 0; $i -lt $Value.Length; $i++) { $copy[$i] = Copy-MtADQueryResult -Value $Value[$i] }
        return ,$copy
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $copy = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) { $copy[$property.Name] = Copy-MtADQueryResult -Value $property.Value }
        $result = [pscustomobject]$copy
        $result.PSObject.TypeNames.Insert(0, $Value.PSObject.TypeNames[0])
        return $result
    }
    return $Value
}
