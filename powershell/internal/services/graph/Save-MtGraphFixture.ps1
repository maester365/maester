function Save-MtGraphFixture {
    <#
    .SYNOPSIS
    Internal: Writes the fixture file of one Graph request and response.

    .DESCRIPTION
    A fixture file holds the request (method, decoded relative uri, key and body) and the response (HTTP status and
    body). The request is kept so that a person can see what the file answers and so that Update-MtGraphFixtureIndex
    can check the file name against the key. Headers are never written: there is no token or authorization header
    in a fixture.

        {
          "request": { "method": "GET", "uri": "v1.0/organization", "key": "GET v1.0/organization" },
          "response": { "status": 200, "body": { "value": [ ... ] } }
        }

    .EXAMPLE
    Save-MtGraphFixture -Folder ./fixtures/default -KeyInfo $key -Status 200 -Body $node

    Writes ./fixtures/default/graph/<file name of the key>.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The folder of the fixture set (scenario).
        [Parameter(Mandatory)]
        [string] $Folder,

        # The key of the request, from Get-MtGraphFixtureKey.
        [Parameter(Mandatory)]
        [object] $KeyInfo,

        # The HTTP status of the response.
        [Parameter(Mandatory)]
        [int] $Status,

        # The response body.
        [Parameter()]
        [AllowNull()]
        [System.Text.Json.Nodes.JsonNode] $Body,

        # The request body, when the request had one.
        [Parameter()]
        [AllowNull()]
        [System.Text.Json.Nodes.JsonNode] $RequestBody,

        # A note for people reading the file, such as what a hand-written fixture is for.
        [Parameter()]
        [string] $Note
    )

    $request = [System.Text.Json.Nodes.JsonObject]::new()
    $request.Add('method', [System.Text.Json.Nodes.JsonValue]::Create([string]$KeyInfo.Method))
    $request.Add('uri', [System.Text.Json.Nodes.JsonValue]::Create([string]$KeyInfo.RelativeUri))
    $request.Add('key', [System.Text.Json.Nodes.JsonValue]::Create([string]$KeyInfo.Key))
    if ($null -ne $RequestBody) { $request.Add('body', $RequestBody.DeepClone()) }

    $response = [System.Text.Json.Nodes.JsonObject]::new()
    $response.Add('status', [System.Text.Json.Nodes.JsonValue]::Create([int]$Status))
    # Assigned, not piped: a JSON object is enumerable and would be unrolled by an if expression.
    $bodyCopy = $null
    if ($null -ne $Body) { $bodyCopy = $Body.DeepClone() }
    $response.Add('body', $bodyCopy)

    $document = [System.Text.Json.Nodes.JsonObject]::new()
    if ($Note) { $document.Add('note', [System.Text.Json.Nodes.JsonValue]::Create([string]$Note)) }
    $document.Add('request', $request)
    $document.Add('response', $response)

    $graphFolder = Join-Path $Folder 'graph'
    if (-not (Test-Path -LiteralPath $graphFolder -PathType Container)) { $null = New-Item -Path $graphFolder -ItemType Directory -Force }
    $file = Join-Path $graphFolder $KeyInfo.FileName
    $json = (ConvertTo-MtGraphFixtureJson -Node $document) + "`n"
    [System.IO.File]::WriteAllText($file, $json, [System.Text.UTF8Encoding]::new($false))
    return $file
}
