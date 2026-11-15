function Invoke-MtGraphTransport {
    <#
    .SYNOPSIS
    Internal: Sends one request to Microsoft Graph, or records it, or answers it from a fixture set.

    .DESCRIPTION
    Every Microsoft Graph read in Maester goes through here: Invoke-MtGraphRequestCache (and so Invoke-MtGraphRequest,
    its paging and batching) and the few helpers that call Graph directly. With Graph record and replay off, which is
    the default, it calls Invoke-MgGraphRequest with exactly the parameters it was given.

    Record (Enable-MtGraphFixture -Mode Record): the request goes to Graph, and its response is written to the
    fixture set, sanitised (Protect-MtGraphFixtureData) unless the recording was started with -NoSanitize.
    - A paged response gets a stable nextLink in its fixture ($skiptoken=maester-page-<n>), and the real nextLink
      is mapped to it, so the next page is stored under a key that does not depend on Graph's skip token.
    - A batch is stored as one fixture per request in it, so replay answers the same requests whether or not they
      are batched, and in any batch size.
    - A 4xx response other than 429 is stored with its status and error body, and the error is thrown on.
      Throttling and server errors are not stored.

    Replay (Enable-MtGraphFixture -Mode Replay): nothing is sent. The response is read from the fixture set, a stored
    error response is thrown as the error Invoke-MgGraphRequest throws, and a request with no fixture throws an error
    that names it and is added to the missing fixtures of the run (Get-MtGraphFixtureStatus).

    The response is converted to -OutputType in the same way in record and replay (ConvertFrom-MtGraphFixtureResponse),
    so a test sees the same objects in both.

    .EXAMPLE
    Invoke-MtGraphTransport -Method GET -Uri 'v1.0/organization' -OutputType PSObject

    Returns the organization, from Graph or from the active fixture set.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The request uri: relative (routed by the Graph environment) or absolute.
        [Parameter(Mandatory)]
        [Uri] $Uri,

        # The HTTP method.
        [Parameter()]
        [string] $Method = 'GET',

        # Request headers. Not stored in fixtures.
        [Parameter()]
        [System.Collections.IDictionary] $Headers,

        # The -OutputType of Invoke-MgGraphRequest.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $OutputType,

        # The request body.
        [Parameter()]
        [AllowNull()]
        [object] $Body
    )

    $state = $__MtSession.GraphFixture
    if (-not $state -or $state.Mode -notin 'Record', 'Replay') {
        # Off: the call the caller made before record and replay existed.
        return Invoke-MgGraphRequest @PSBoundParameters
    }

    $uriString = $Uri.OriginalString
    $bodyText = if ($null -eq $Body) { $null } elseif ($Body -is [string]) { $Body } else { ConvertTo-Json -InputObject $Body -Depth 20 -Compress }
    $requestKey = Get-MtGraphFixtureKey -Uri $uriString -Method $Method -Body $bodyText
    $isBatch = $requestKey.Path -eq '$batch'
    $folder = $state.Folder

    $missingError = {
        param([object[]] $Keys)
        foreach ($k in $Keys) {
            if (-not $state.Missing.Contains($k.Key)) {
                $state.Missing[$k.Key] = [pscustomobject]@{ Key = $k.Key; Method = $k.Method; Uri = $k.RelativeUri; File = "graph/$($k.FileName)"; Count = 0 }
            }
            $state.Missing[$k.Key].Count++
        }
        New-MtGraphFixtureError -Missing @($Keys | ForEach-Object Key) -File @($Keys | ForEach-Object FileName) -Folder $folder -Uri $uriString
    }

    if ($state.Mode -eq 'Replay') {
        if (-not $isBatch) {
            $fixture = Read-MtGraphFixture -Folder $folder -KeyInfo $requestKey
            if (-not $fixture) { $PSCmdlet.ThrowTerminatingError((& $missingError @($requestKey))) }
            $state.Served++
            Write-Verbose "Graph replay: $($requestKey.Key) <- graph/$($requestKey.FileName)"
            if ($fixture.Status -ge 400) {
                $PSCmdlet.ThrowTerminatingError((New-MtGraphFixtureError -Status $fixture.Status -Body $fixture.Body -Uri $requestKey.RelativeUri))
            }
            return ConvertFrom-MtGraphFixtureResponse -Json $fixture.Body -OutputType $OutputType
        }

        # A batch is answered request by request.
        $batch = [System.Text.Json.Nodes.JsonNode]::Parse($bodyText)
        $responses = [System.Text.Json.Nodes.JsonArray]::new()
        $missing = [System.Collections.Generic.List[object]]::new()
        foreach ($subRequest in @($batch['requests'])) {
            $subBody = if ($null -ne $subRequest['body']) { $subRequest['body'].ToJsonString() } else { $null }
            $subKey = Get-MtGraphFixtureKey -Uri ($subRequest['url'].GetValue[string]()) -Method ($subRequest['method'].GetValue[string]()) -Body $subBody -ApiVersion $requestKey.ApiVersion
            $fixture = Read-MtGraphFixture -Folder $folder -KeyInfo $subKey
            if (-not $fixture) { $missing.Add($subKey); continue }
            $state.Served++
            $subResponse = [System.Text.Json.Nodes.JsonObject]::new()
            $subResponse.Add('id', $subRequest['id'].DeepClone())
            $subResponse.Add('status', [System.Text.Json.Nodes.JsonValue]::Create([int]$fixture.Status))
            $subResponse.Add('headers', [System.Text.Json.Nodes.JsonObject]::new())
            # Assigned, not piped: a JSON object is enumerable and would be unrolled by an if expression.
            $subResponseBody = $null
            if ($fixture.Body) { $subResponseBody = [System.Text.Json.Nodes.JsonNode]::Parse($fixture.Body) }
            $subResponse.Add('body', $subResponseBody)
            $responses.Add($subResponse)
        }
        if ($missing.Count -gt 0) { $PSCmdlet.ThrowTerminatingError((& $missingError $missing.ToArray())) }
        $batchResponse = [System.Text.Json.Nodes.JsonObject]::new()
        $batchResponse.Add('responses', $responses)
        return ConvertFrom-MtGraphFixtureResponse -Json $batchResponse.ToJsonString() -OutputType $OutputType
    }

    # Record.
    $protect = {
        param([string] $Text, [switch] $IsUri)
        if (-not $state.Sanitize -or [string]::IsNullOrEmpty($Text)) { return $Text }
        Protect-MtGraphFixtureData -Text $Text -Uri:$IsUri -State $state
    }
    $protectNode = {
        param($Node)
        if ($state.Sanitize -and $null -ne $Node) { Protect-MtGraphFixtureData -Node $Node -State $state }
    }
    $parseBody = {
        param([string] $Text)
        if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
        try { , [System.Text.Json.Nodes.JsonNode]::Parse($Text) } catch { , [System.Text.Json.Nodes.JsonValue]::Create([string]$Text) }
    }

    # The key a request is stored under: its sanitised uri, or for a next page the stable link its fixture points to.
    $keyFor = {
        param([string] $RequestUri, [string] $RequestMethod, [string] $RequestBody, [string] $ApiVersion)
        $keyUri = if ($state.NextLinks.ContainsKey($RequestUri)) { $state.NextLinks[$RequestUri] } else { & $protect $RequestUri -IsUri }
        $keyBodyNode = & $parseBody $RequestBody
        & $protectNode $keyBodyNode
        $keyBody = if ($null -ne $keyBodyNode) { $keyBodyNode.ToJsonString() } else { $null }
        [pscustomobject]@{
            Key      = Get-MtGraphFixtureKey -Uri $keyUri -Method $RequestMethod -Body $keyBody -ApiVersion $ApiVersion
            BodyNode = $keyBodyNode
        }
    }

    $store = {
        param($Stored, [int] $Status, $BodyNode)
        if ($BodyNode -is [System.Text.Json.Nodes.JsonObject]) {
            $realNextLink = if ($null -ne $BodyNode['@odata.nextLink']) { $BodyNode['@odata.nextLink'].GetValue[string]() } else { $null }
            if ($realNextLink) {
                # Graph's skip token changes from one recording to the next and can carry tenant data: the fixture
                # points to a stable link instead, on the same host, and the real link is mapped to it.
                $page = 2
                $kept = foreach ($pair in $Stored.Key.Query) {
                    if ($pair.Name -eq '$skiptoken' -and $pair.Value -match '^maester-page-(\d+)$') { $page = [int]$Matches[1] + 1; continue }
                    if ($pair.Name -in '$skiptoken', '$skip') { continue }
                    '{0}={1}' -f $pair.Name, [uri]::EscapeDataString($pair.Value)
                }
                $origin = ([uri]$realNextLink).GetLeftPart([System.UriPartial]::Authority)
                $stableLink = '{0}/{1}/{2}?{3}' -f $origin, $Stored.Key.ApiVersion, $Stored.Key.Path, ((@($kept) + "`$skiptoken=maester-page-$page") -join '&')
                $state.NextLinks[$realNextLink] = $stableLink
                $null = $BodyNode.Remove('@odata.nextLink')
            }
            & $protectNode $BodyNode
            if ($realNextLink) { $BodyNode['@odata.nextLink'] = [System.Text.Json.Nodes.JsonValue]::Create([string]$stableLink) }
        } else {
            & $protectNode $BodyNode
        }
        $null = Save-MtGraphFixture -Folder $folder -KeyInfo $Stored.Key -Status $Status -Body $BodyNode -RequestBody $Stored.BodyNode
        $state.Recorded++
        Write-Verbose "Graph record: $($Stored.Key.Key) -> graph/$($Stored.Key.FileName)"
    }

    $graphParameters = @{} + $PSBoundParameters
    $graphParameters.OutputType = 'Json'
    if (-not $isBatch) { $stored = & $keyFor $uriString $Method $bodyText $requestKey.ApiVersion }

    try {
        $raw = Invoke-MgGraphRequest @graphParameters
    } catch {
        $errorRecord = $_
        $response = $errorRecord.Exception.Response
        $status = if ($response) { [int]$response.StatusCode } else { 0 }
        if (-not $isBatch -and $status -ge 400 -and $status -lt 500 -and $status -ne 429) {
            # Checks branch on 403 and 404, so the error response is a fixture too. Only its JSON body is kept: the
            # message of the SDK's error also holds the response headers.
            $errorBody = $null
            foreach ($text in @($errorRecord.ErrorDetails.Message, $errorRecord.Exception.Message)) {
                if (-not $text) { continue }
                $start = $text.IndexOf('{')
                $end = $text.LastIndexOf('}')
                if ($start -lt 0 -or $end -le $start) { continue }
                try {
                    $errorBody = [System.Text.Json.Nodes.JsonNode]::Parse($text.Substring($start, $end - $start + 1))
                    break
                } catch {
                    Write-Debug "Not a JSON error body: $_"
                }
            }
            if ($errorBody -isnot [System.Text.Json.Nodes.JsonObject] -or $null -eq $errorBody['error']) {
                $errorBody = [System.Text.Json.Nodes.JsonNode]::Parse(('{{"error":{{"code":"{0}","message":"Recorded without an error body."}}}}' -f [System.Net.HttpStatusCode]$status))
            }
            if ($errorBody['error'] -is [System.Text.Json.Nodes.JsonObject]) {
                # Request IDs and dates differ on every call and say nothing about the tenant's configuration.
                $null = $errorBody['error'].AsObject().Remove('innerError')
                $null = $errorBody['error'].AsObject().Remove('innererror')
            }
            & $store $stored $status $errorBody
        }
        throw
    }

    if (-not $isBatch) {
        & $store $stored 200 (& $parseBody $raw)
    } else {
        $batchRequests = @{}
        foreach ($subRequest in @(([System.Text.Json.Nodes.JsonNode]::Parse($bodyText))['requests'])) { $batchRequests[$subRequest['id'].ToJsonString().Trim('"')] = $subRequest }
        $batchResponse = & $parseBody $raw
        foreach ($subResponse in @($batchResponse['responses'])) {
            $status = $subResponse['status'].GetValue[int]()
            # Throttled and failed requests are sent again by Invoke-MtGraphRequest: only final answers are stored.
            if ($status -eq 429 -or $status -ge 500) { continue }
            $subRequest = $batchRequests[$subResponse['id'].ToJsonString().Trim('"')]
            if (-not $subRequest) { continue }
            $subBody = if ($null -ne $subRequest['body']) { $subRequest['body'].ToJsonString() } else { $null }
            $subStored = & $keyFor ($subRequest['url'].GetValue[string]()) ($subRequest['method'].GetValue[string]()) $subBody $requestKey.ApiVersion
            $subResponseBody = $null
            if ($null -ne $subResponse['body']) { $subResponseBody = $subResponse['body'].DeepClone() }
            if ($subResponseBody -is [System.Text.Json.Nodes.JsonObject] -and $null -ne $subResponseBody['error'] -and $subResponseBody['error'] -is [System.Text.Json.Nodes.JsonObject]) {
                $null = $subResponseBody['error'].AsObject().Remove('innerError')
            }
            & $store $subStored $status $subResponseBody
        }
    }
    return ConvertFrom-MtGraphFixtureResponse -Json $raw -OutputType $OutputType
}
