function Invoke-MtPowerPlatformRequest {
    <#
    .SYNOPSIS
    Calls the Power Platform admin (Business Application Platform) API.

    .DESCRIPTION
    Uses the active Azure context to acquire a Power Platform access token and calls the endpoint for the signed-in
    cloud. Collection responses that carry a nextLink are followed and combined into one value array.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # Path and query of the request, relative to the Power Platform admin API host.
        [Parameter(Mandatory)]
        [string] $RelativeUri,

        # HTTP method of the request.
        [ValidateSet('Get', 'Post')]
        [string] $Method = 'Get'
    )

    $azureEnvironment = (Get-AzContext -ErrorAction Stop).Environment.Name
    $endpoints = @{
        AzureCloud        = @{ BaseUri = 'https://api.bap.microsoft.com'; ResourceUrl = 'https://service.powerapps.com/' }
        AzureUSGovernment = @{ BaseUri = 'https://high.api.bap.microsoft.us'; ResourceUrl = 'https://high.service.powerapps.us/' }
    }
    $endpoint = $endpoints[$azureEnvironment]
    if (-not $endpoint) {
        throw "The Power Platform admin API is not supported for the '$azureEnvironment' Azure environment."
    }

    $accessToken = Get-AzAccessToken -ResourceUrl $endpoint.ResourceUrl -AsSecureString -ErrorAction Stop
    if (-not $accessToken.Token) {
        throw 'The connected Azure context did not return a Power Platform access token.'
    }

    $requestUri = "$($endpoint.BaseUri)$RelativeUri"
    $values = [System.Collections.Generic.List[object]]::new()
    while (-not [string]::IsNullOrEmpty($requestUri)) {
        $response = Invoke-RestMethod -Method $Method `
            -Uri $requestUri `
            -Authentication Bearer `
            -Token $accessToken.Token `
            -ContentType 'application/json' `
            -ErrorAction Stop

        if ($null -eq $response -or $response -is [string] -or $null -eq $response.PSObject.Properties['value']) {
            return $response
        }

        foreach ($value in @($response.value)) {
            if ($null -ne $value) {
                $values.Add($value)
            }
        }

        $nextLink = $response.PSObject.Properties['nextLink']
        if ($null -eq $nextLink) {
            $requestUri = $null
        }
        else {
            $requestUri = $nextLink.Value
        }
    }

    return [pscustomobject]@{ value = $values.ToArray() }
}
