<#
    .SYNOPSIS
        Get directory objects by their object id's.
    .DESCRIPTION
        This function retrieves directory objects from Microsoft Graph by their object id's.
        It is a wrapper around the Microsoft Graph API endpoint "directoryObjects/getByIds".
        The function takes an array of object id's as input and returns the corresponding directory objects.
#>

function Get-MtDirectoryObjects {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple tests')]
    [CmdletBinding()]
    param(
        # The object id's of the directory objects to retrieve.
        [Parameter(Mandatory = $true)]
        [string[]] $ObjectId,

        # If true, returns the objects as markdown.
        [switch] $AsMarkdown = $false
    )

    $postBody = @{
        ids = $ObjectId
    } | ConvertTo-Json

    $graphUrl = 'beta/directoryObjects/getByIds?$select=id,displayName'
    $result = Invoke-MgGraphRequest -Uri $graphUrl -Method POST -Body $postBody -OutputType PSObject
    $values = Get-ObjectProperty $result 'value'
    if($AsMarkdown) {
        $values = Get-GraphObjectMarkdown -GraphObjects $values
    }
    return $values
}