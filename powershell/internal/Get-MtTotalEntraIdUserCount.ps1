function Get-MtTotalEntraIdUserCount {
    [CmdletBinding()]
    [OutputType([int])]
    param ()

    $TotalUserCount = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/users?$count=true' -Headers @{"ConsistencyLevel" = "eventual" } | Select-Object -ExpandProperty '@odata.count'

    return $TotalUserCount
}