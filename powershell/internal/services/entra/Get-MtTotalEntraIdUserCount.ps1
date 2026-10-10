function Get-MtTotalEntraIdUserCount {
    <#
    .SYNOPSIS
    Returns the total number of users from the Microsoft Graph API.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param ()

    $result = Invoke-MgGraphRequest -Uri '/beta/users?$count=true' -Headers @{"ConsistencyLevel" = "eventual" }
    $TotalUserCount = $result.'@odata.count'

    return $TotalUserCount
}
