function Invoke-MtGraphRequest {
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
        # Filters results (rows). https://docs.microsoft.com/graph/query-parameters#filter-parameter
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
        # An explicit -GraphBaseUri is an intentional absolute endpoint override. Without one the
        # endpoint is read from the active Graph context on every invocation, so a context switch
        # inside a single session is picked up instead of reusing a stale session value.
        [bool] $IsEndpointOverride = -not [string]::IsNullOrEmpty($GraphBaseUri)
        if (!$IsEndpointOverride) {
            $MgContext = Get-MgContext
            if (-not $MgContext -or [string]::IsNullOrEmpty($MgContext.Environment)) {
                throw "No active Microsoft Graph context. Ensure you are connected via 'Connect-Maester', or pass -GraphBaseUri to target an endpoint explicitly."
            }
            # Resolved on every invocation, not memoised. Memoising by environment name misses
            # an endpoint changed under that same name by Add-MgEnvironment or
            # Set-MgEnvironment, and the stale endpoint would then also produce the absolute
            # cache key, so a request could be answered from the previous endpoint's entry.
            # Measured cost of not caching it: Get-MgEnvironment is 0.031 ms per call against
            # a Graph round trip of tens of milliseconds.
            [string] $EnvironmentName = $MgContext.Environment
            Write-Verbose -Message ("Resolving the Graph endpoint for environment '{0}'." -f $EnvironmentName)
            $GraphBaseUri = [uri] $((Get-MgEnvironment -Name $EnvironmentName).GraphEndpoint)
        }
        # Exposed for callers that read the session value; no longer used to route requests.
        $__MtSession.GraphBaseUri = $GraphBaseUri

        # The endpoint itself can carry a path, for example a reverse proxy in front of Graph. A base
        # that does not end in a slash makes its last segment look like a document, which would put
        # that segment back into any uri made relative to it. Normalising the base once, here, is what
        # keeps the rest of this function from having to care whether the endpoint has a path.
        [uri] $TransportBaseUri = [uri] ($GraphBaseUri.AbsoluteUri.TrimEnd('/') + '/')

        # Whether a relative transport uri is safe for THIS endpoint. Measured against
        # Microsoft.Graph.Authentication 2.41.2 by calling InvokeMgGraphRequest.PrepareUri
        # directly: it builds a relative request from the base address's scheme and host only,
        # so both the endpoint's own path and an explicit port are dropped.
        #
        #   base https://graph.microsoft.com/          + v1.0/users -> https://graph.microsoft.com/v1.0/users
        #   base https://proxy.contoso.com/graph/      + v1.0/users -> https://proxy.contoso.com/v1.0/users
        #   base https://proxy.contoso.com:8443/graph/ + v1.0/users -> https://proxy.contoso.com/v1.0/users
        #
        # A relative uri is therefore only equivalent when the endpoint is a bare host on the
        # default port, which every published Microsoft cloud is. Anything else -- a reverse
        # proxy with a path, a non-default port -- goes out absolute, where nothing is dropped.
        [bool] $RelativeIsSafe = ($TransportBaseUri.AbsolutePath -eq '/') -and $TransportBaseUri.IsDefaultPort

        # Versioned root that every uri in this invocation is built from. Batch subrequest urls are
        # relative to it, so the base and the api version come off together and a base uri that
        # carries a path of its own does not leak into the subrequest. Built through UriBuilder so
        # it is normalised exactly like the request uris it is compared against.
        [string] $VersionedBaseUri = (New-Object System.UriBuilder -ArgumentList ($TransportBaseUri.AbsoluteUri + $ApiVersion)).Uri.AbsoluteUri.TrimEnd('/') + '/'

        $listRequests = New-Object 'System.Collections.Generic.List[psobject]'

        # The override-versus-relative decision lives here only, so the single-request path and the
        # batch path cannot drift apart. Relative by default is what lets Microsoft Graph PowerShell
        # route to the connected environment; absolute only when the caller overrode the endpoint.
        function Resolve-TransportUri ([uri] $RequestUri) {
            if ($IsEndpointOverride -or -not $RelativeIsSafe) { return $RequestUri.AbsoluteUri }
            return $TransportBaseUri.MakeRelativeUri($RequestUri).ToString()
        }

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
                        url     = $uriQueryEndpointFinal.Uri.AbsoluteUri -replace ('^{0}' -f [regex]::Escape($VersionedBaseUri)), ''
                        headers = @{ ConsistencyLevel = $ConsistencyLevel }
                    }
                    $listRequests.Add($request)
                } else {
                    # The cache key stays absolute, which is what keeps entries from one
                    # environment from being served to another.
                    $results = Invoke-MtGraphRequestCache -Method $($Method) -Uri (Resolve-TransportUri $uriQueryEndpointFinal.Uri) -CacheKey $uriQueryEndpointFinal.Uri.AbsoluteUri -Headers @{ ConsistencyLevel = $ConsistencyLevel } -OutputType $OutputType -DisableCache:$DisableCache -Body $Body
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

                $resultsBatch = Invoke-MtGraphRequestCache -Method POST -Uri (Resolve-TransportUri $uriQueryEndpoint.Uri) -CacheKey $uriQueryEndpoint.Uri.AbsoluteUri -Body $jsonRequests -OutputType $OutputType -DisableCache:$DisableCache
                $resultsBatch = $resultsBatch.responses | Sort-Object -Property id

                foreach ($results in ($resultsBatch.body)) {
                    Complete-Result $results $DisablePaging
                }
            }
        }
    }
}
