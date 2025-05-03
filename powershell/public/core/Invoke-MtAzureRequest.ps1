<#
    .SYNOPSIS
    Invoke a REST API request to the Azure Management API.

    .DESCRIPTION
    This function allows you to make REST API requests to the Azure Management API.
    It is a wrapper around the Invoke-AzRest function, providing a simplified interface.

    .EXAMPLE
    Invoke-MtAzureRequest -RelativeUri 'subscriptions'


    .LINK
    https://maester.dev/docs/commands/Invoke-MtAzureRequest
#>

function Invoke-MtAzureRequest {
    [CmdletBinding()]
    param(
        # Graph endpoint such as "users".
        [Parameter(Mandatory = $true)]
        [string[]] $RelativeUri,

        # The HTTP method to use. Default is GET.
        [Parameter(Mandatory = $false)]
        [ValidateSet("GET")]
        [string] $Method = "GET",

        # The API version to use. Default is 2024-11-01
        [Parameter(Mandatory = $false)]
        $ApiVersion = '2024-11-01',

        # The filter to use.
        [Parameter(Mandatory = $false)]
        [string] $Filter
    )

    $resourceUrl = (Get-AzContext).Environment.ResourceManagerUrl
    $restApi = "$($resourceUrl)$($RelativeUri)?api-version=$($ApiVersion)"
    if ($Filter) {
        $restApi += '&$Filter=' + $Filter
    }

    Write-Verbose "Invoke-AzRest $restApi"
    $result = Invoke-AzRest -Method $Method -Uri $restApi
    return $result.Content | ConvertFrom-Json
}