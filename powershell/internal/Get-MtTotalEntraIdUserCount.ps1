<#
.SYNOPSIS
    Returns the total number of users from the Microsoft Graph API.
#>

function Get-MtTotalEntraIdUserCount {
    [CmdletBinding()]
    [OutputType([int])]
    param ()

    $result = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/users?$count=true' -Headers @{"ConsistencyLevel" = "eventual" }
    $TotalUserCount = $result.'@odata.count'

    return $TotalUserCount
}