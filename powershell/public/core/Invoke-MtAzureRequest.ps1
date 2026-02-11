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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Justification = 'Invoke-MtAzureRequest is required')]
    [CmdletBinding()]
    param(
        # Graph endpoint such as "users".
        [Parameter(Mandatory = $true)]
        [Alias('Path')]
        [string] $RelativeUri,

        # The HTTP method to use. Default is GET.
        [Parameter(Mandatory = $false)]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE', 'PUT')]
        [string] $Method = 'GET',

        # The API version to use. Default is 2024-11-01
        [Parameter(Mandatory = $false)]
        $ApiVersion = '2024-11-01',

        # Filter parameters to include in the request. E.g. "displayName eq 'John'"
        [Parameter(Mandatory = $false)]
        [string] $Filter,

        # Select parameters to include in the request. E.g. "id,displayName"
        [Parameter(Mandatory = $false)]
        [string] $Select,

        # The body payload for POST/PATCH/PUT requests
        [Parameter(Mandatory = $false)]
        [Alias('Body')]
        [string] $Payload = $null,

        # Use Microsoft Graph endpoint. Defaults to Azure Resource Manager, if enabled requests will go to Microsoft Graph
        [Parameter(Mandatory = $false)]
        [switch] $Graph
    )

    # Build params to be sent to Invoke-AzRest
    $params = @{
        Method = $Method
    }

    if ($Payload) {
        $params['Payload'] = $Payload
    }

    if ($Graph) {
        $baseUri = $((Get-AzContext).Environment.ExtendedProperties.MicrosoftGraphUrl)
        if ( -not $baseUri) { $baseUri = 'https://graph.microsoft.com' }
        if ($ApiVersion -ne 'v1.0' -and $ApiVersion -ne 'beta') { $ApiVersion = 'v1.0' }

        $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList ([IO.Path]::Combine($baseUri, $ApiVersion, $RelativeUri))

        ## Combine query parameters from URI and cmdlet parameters
        if ($uriQueryEndpoint.Query) {
            [hashtable] $finalQueryParameters = ConvertFrom-QueryString $uriQueryEndpoint.Query -AsHashtable
            if ($QueryParameters) {
                foreach ($ParameterName in $QueryParameters.Keys) {
                    $finalQueryParameters[$ParameterName] = $QueryParameters[$ParameterName]
                }
            }
        } elseif ($QueryParameters) { [hashtable] $finalQueryParameters = $QueryParameters }
        else { [hashtable] $finalQueryParameters = @{ } }
        if ($Select) { $finalQueryParameters['$select'] = $Select -join ',' }
        if ($Filter) { $finalQueryParameters['$filter'] = $Filter }
        $uriQueryEndpoint.Query = ConvertTo-QueryString $finalQueryParameters

        $params['Uri'] = $uriQueryEndpoint.Uri
    } else {
        $path = $RelativeUri + "?api-version=$ApiVersion"
        if ($Filter) {
            $path += '&$Filter=' + $Filter
        }

        $params['Path'] = $path
    }

    Write-Verbose "Invoking REST method: $Method $($params['Uri'] -or $params['Path'])"
    Write-Verbose ($params | ConvertTo-Json -Depth 3)
    $result = Invoke-AzRest @params
    return $result.Content | ConvertFrom-Json
}
