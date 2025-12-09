<#
 .SYNOPSIS
   Enhanced version of Invoke-MgGraphRequest that supports paging, batching and caching.

 .Description
    The version of Invoke-Graph request supports
    * Filter, Select and Unique IDs as parameters
    * Automatic paging if Graph returns a nextLink
    * Batching of requests to Graph if multiple requests are piped through
    * Caching of results for the duration of the session
    * Ability to skip cache and go directly to Graph
    * Specify consistency level as a parameter

    :::info
    Note: Batch requests don't support caching.
    :::

 .Example
    Invoke-MtGraph -RelativeUri "users" -Filter "displayName eq 'John Doe'" -Select "displayName"

    Get all users with a display name of "John Doe" and return the first 10 results.

.LINK
    https://maester.dev/docs/commands/Invoke-MtGraphRequest
#>
function Invoke-MtGraphRequest {
    [CmdletBinding()]
    param(
        # Graph endpoint such as "users".
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]] $RelativeUri,
        # Specifies unique Id(s) for the URI endpoint. For example, users endpoint accepts Id or UPN.
        [Parameter(Mandatory = $false)]
        [string[]] $UniqueId,
        # Filters properties (columns).
        [Parameter(Mandatory = $false)]
        [string[]] $Select,
        # Filters results (rows). https://docs.microsoft.com/en-us/graph/query-parameters#filter-parameter
        [Parameter(Mandatory = $false)]
        [string] $Filter,
        # Parameters such as "$top".
        [Parameter(Mandatory = $false)]
        [hashtable] $QueryParameters,
        # API Version.
        [Parameter(Mandatory = $false)]
        [ValidateSet('v1.0', 'beta')]
        [string] $ApiVersion = 'v1.0',
        # HTTP Method to use for the request.
        [Parameter(Mandatory = $false)]
        [ValidateSet('GET', 'POST')]
        [string] $Method = 'GET',
        # Body for POST requests.
        [Parameter(Mandatory = $false)]
        [string] $Body,
        # Specifies consistency level.
        [Parameter(Mandatory = $false)]
        [string] $ConsistencyLevel = 'eventual',
        # Only return first page of results.
        [Parameter(Mandatory = $false)]
        [switch] $DisablePaging,
        # Force individual requests to MS Graph.
        [Parameter(Mandatory = $false)]
        [switch] $DisableBatching,
        # Specify Batch size.
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20,
        # Base URL for Microsoft Graph API.
        [Parameter(Mandatory = $false)]
        [uri] $GraphBaseUri,
        # Specify if this request should skip cache and go directly to Graph.
        [Parameter(Mandatory = $false)]
        [switch] $DisableCache,
        # Specify the output type
        [Parameter(Mandatory = $false)]
        [ValidateSet('PSObject', 'PSCustomObject', 'Hashtable')]
        [string] $OutputType = 'PSObject'
    )

    begin {
        if ([string]::IsNullOrEmpty($GraphBaseUri)) {
            if ([string]::IsNullOrEmpty($__MtSession.GraphBaseUri)) {
                Write-Verbose -Message "Setting GraphBaseUri to default value from MgContext."
                $__MtSession.GraphBaseUri = $((Get-MgEnvironment -Name (Get-MgContext).Environment).GraphEndpoint)
            }
        }
        $GraphBaseUri = $__MtSession.GraphBaseUri

        $listRequests = New-Object 'System.Collections.Generic.List[psobject]'

        function Format-Result ($results, $RawOutput) {
            # Check if 'value' property exists (not just truthy) to handle empty arrays
            $hasValueProperty = $null -ne $results -and $results.PSObject.Properties.Match('value').Count -gt 0
            if (!$RawOutput -and $hasValueProperty) {
                $dataContextName = '@odata.context'
                foreach ($result in $results.value) {
                    if ($result -is [hashtable]) {
                        if (!$result.ContainsKey($dataContextName)) {
                            $result.Add($dataContextName, ('{0}/$entity' -f $results.'@odata.context'))
                        }
                    } else {
                        if (![bool]$results.PSObject.Properties[$dataContextName]) {
                            $result | Add-Member -MemberType NoteProperty -Name $dataContextName -Value ('{0}/$entity' -f $results.'@odata.context')
                        }
                    }
                    Write-Output $result
                }
            } else { Write-Output $results }
        }

        function Complete-Result ($results, $DisablePaging) {
            if (!$DisablePaging -and $results -and (Get-ObjectProperty $results '@odata.nextLink')) {
                # The "skipToken" are in rare cases not unique, so when it is processed, we can end up in a caching loop. By updating the cache with the original uri with the final result, we workaround this issue and have a faster cache.
                $resultList = New-Object -TypeName System.Collections.ArrayList
                $resultList.AddRange(@($results.value))
                do {
                    $results = Invoke-MtGraphRequestCache -Method $($Method) -Uri $results.'@odata.nextLink' -Headers @{ ConsistencyLevel = $ConsistencyLevel } -OutputType $OutputType -DisableCache # Do not use cache as "skipTokens" is not always unique in large datasets and we may end with a loop
                    $resultList.AddRange(@($results.value))
                } while (Get-ObjectProperty $results '@odata.nextLink')
                $results.value = $resultList
                # Update the original request cache with the consolidated results
                if (!$DisableCache) {
                    $__MtSession.GraphCache[$uriQueryEndpointFinal.Uri.AbsoluteUri] = $results
                }
            }
            Format-Result $results $DisablePaging
        }
    }

    process {
        ## Initialize
        $results = $null

        if (!$UniqueId) { [string[]] $UniqueId = '' }
        if ($DisableBatching -and ($RelativeUri.Count -gt 1 -or $UniqueId.Count -gt 1)) {
            Write-Warning ('This command is invoking {0} individual Graph requests. For better performance, remove the -DisableBatching parameter.' -f ($RelativeUri.Count * $UniqueId.Count))
        }

        ## Process Each RelativeUri
        foreach ($uri in $RelativeUri) {
            $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList ([IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $ApiVersion, $uri))

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

            ## Invoke graph requests individually or save for single batch request
            foreach ($id in $UniqueId) {
                $uriQueryEndpointFinal = New-Object System.UriBuilder -ArgumentList $uriQueryEndpoint.Uri
                $uriQueryEndpointFinal.Path = ([IO.Path]::Combine($uriQueryEndpointFinal.Path, $id))

                if (!$DisableBatching -and ($RelativeUri.Count -gt 1 -or $UniqueId.Count -gt 1)) {
                    ## Create batch request entry
                    $request = New-Object PSObject -Property @{
                        id      = $listRequests.Count #(New-Guid).ToString()
                        method  = $($Method)
                        url     = $uriQueryEndpointFinal.Uri.AbsoluteUri -replace ('{0}{1}/' -f $GraphBaseUri.AbsoluteUri, $ApiVersion)
                        headers = @{ ConsistencyLevel = $ConsistencyLevel }
                    }
                    $listRequests.Add($request)
                } else {
                    $results = Invoke-MtGraphRequestCache -Method $($Method) -Uri $uriQueryEndpointFinal.Uri.AbsoluteUri -Headers @{ ConsistencyLevel = $ConsistencyLevel } -OutputType $OutputType -DisableCache:$DisableCache -Body $Body
                    Complete-Result $results $DisablePaging
                }
            }
        }
    }

    end {
        if ($listRequests.Count -gt 0) {
            $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList ([IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $ApiVersion, '$batch'))
            for ($iRequest = 0; $iRequest -lt $listRequests.Count; $iRequest += $BatchSize) {
                $indexEnd = [System.Math]::Min($iRequest + $BatchSize - 1, $listRequests.Count - 1)
                $jsonRequests = New-Object psobject -Property @{ requests = $listRequests[$iRequest..$indexEnd] } | ConvertTo-Json -Depth 5
                Write-Debug $jsonRequests

                $resultsBatch = Invoke-MtGraphRequestCache -Method POST -Uri $uriQueryEndpoint.Uri.AbsoluteUri -Body $jsonRequests -OutputType $OutputType -DisableCache:$DisableCache
                $resultsBatch = $resultsBatch.responses | Sort-Object -Property id

                foreach ($results in ($resultsBatch.body)) {
                    Complete-Result $results $DisablePaging
                }
            }
        }
    }
}