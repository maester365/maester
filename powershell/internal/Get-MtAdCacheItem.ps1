function Get-MtAdCacheItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Computers','Domains','Forest','Configuration')]
        [string]$Type,
        [string[]]$Properties = @('DistinguishedName','Name'),
        [string]$Filter = '*',
        [string]$Server = $__MtSession.AdServer,
        [pscredential]$Credential = $__MtSession.AdCredential,
        [int]$TtlMinutes = 15
    )

    if (-not $__MtSession.AdCache.ContainsKey($Type)){
        $__MtSession.AdCache[$Type] = @{ LastUpdated = $null; Data = @(); Indexes = @{} }
    }

    $entry = $__MtSession.AdCache[$Type]

    $needFetch = $false
    if ($null -eq $entry.LastUpdated) { $needFetch = $true }
    elseif ((Get-Date) -gt ($entry.LastUpdated.AddMinutes($TtlMinutes))) { $needFetch = $true }

    if (-not $needFetch -and $Filter -eq '*'){
        return $entry.Data
    }

    # Build splat for AD cmdlets
    $splat = @{ Filter = $Filter; Properties = $Properties }
    if ($Server) { $splat.Server = $Server }
    if ($Credential) { $splat.Credential = $Credential }

    try{
        switch ($Type){
            'Computers' { $objects = Get-ADComputer @splat }
            'Domains'   { $objects = Get-ADDomain -Filter $Filter }
            'Forest'    { $objects = Get-ADForest }
            'Configuration' { $objects = Get-ADObject @splat }
        }
    }catch{
        Write-Error $_
        return $null
    }

    # Simplify objects to minimal PSCustomObject with requested properties
    $data = $objects | Select-Object -Property $Properties -Unique

    # Build a simple index by DistinguishedName and Name where available
    $indexes = @{}
    foreach ($o in $data){
        if ($o.PSObject.Properties['DistinguishedName']){
            $dn = $o.DistinguishedName
            $indexes[$dn] = $o
        }
        if ($o.PSObject.Properties['Name']){
            $n = $o.Name
            if (-not $indexes.ContainsKey($n)) { $indexes[$n] = $o }
        }
    }

    $__MtSession.AdCache[$Type] = @{ LastUpdated = (Get-Date); Data = $data; Indexes = $indexes }
    return $__MtSession.AdCache[$Type]
}