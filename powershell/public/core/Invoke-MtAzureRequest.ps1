<#
.SYNOPSIS
    Invoke a REST API request to the Azure Management API.

.DESCRIPTION
    This function allows you to make REST API requests to the Azure Management API.
    It is a wrapper around the Invoke-AzRest function, providing a simplified interface.
#>

function Invoke-MtAzureRequest {
    [CmdletBinding()]
    param(
        # Graph endpoint such as "users".
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]] $RelativeUri,

        # The HTTP method to use. Default is GET.
        [Parameter(Mandatory = $false)]
        [ValidateSet("GET")]
        [string] $Method = "GET",

        # The API version to use. Default is 2022-04-01
        [Parameter(Mandatory = $false)]
        $ApiVersion = '2022-04-01',

        # The filter to use.
        [Parameter(Mandatory = $false)]
        [string] $Filter,

        [Parameter(Mandatory = $false)]
        [ValidateSet('PSObject', 'PSCustomObject', 'Hashtable')]
        [string] $OutputType = 'PSObject'
    )

    $resourceUrl = (Get-AzContext).Environment.ResourceManagerUrl
    $restApi = "$($resourceUrl)$($RelativeUri)?api-version=$($ApiVersion)"
    if ($Filter) {
        $restApi += '&$Filter=' + $Filter
    }

    $result = Invoke-AzRest -Method $Method -Uri $restApi
    return $result.Content | ConvertFrom-Json
}