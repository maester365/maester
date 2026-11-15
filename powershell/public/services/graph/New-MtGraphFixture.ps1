function New-MtGraphFixture {
    <#
    .SYNOPSIS
    Writes a hand-made Graph fixture: the response replay gives for one request.

    .DESCRIPTION
    Use it to write the mock data of a test, or to reproduce a bug, without a tenant. The file gets the name replay
    looks for (from the request's method, uri and body) and the fixture set's index.json is updated.

    Hand-made data is not sanitised: use fake values. Start the IDs of fake objects with fa4efa4e, as recorded
    fixture sets do, and use domains such as contoso.onmicrosoft.com or fabrikam.example.

    To give a test several pages, write the first page with "@odata.nextLink" set to the same uri with
    $skiptoken=maester-page-2 added, and write that uri as the next fixture.

    .PARAMETER Path
    The folder that holds the fixture sets.

    .PARAMETER Scenario
    The fixture set, such as well-configured or badly-configured.

    .PARAMETER Uri
    The request, as a test makes it: 'v1.0/organization', 'beta/policies/authorizationPolicy' or an absolute uri.
    Query parameters can be in any order.

    .PARAMETER Method
    The HTTP method. Defaults to GET.

    .PARAMETER Body
    The request body, for a POST.

    .PARAMETER Response
    The response body: an object, a hashtable or JSON text. Leave it out for an empty response. JSON text is written
    as it is; an object or hashtable is written with its members sorted by name, so the file is the same every time.

    .PARAMETER StatusCode
    The HTTP status. Use 403 or 404 with an error body to test how a check handles a missing permission or object.

    .PARAMETER Note
    A note for people who read the file, such as what the fixture makes the test do.

    .EXAMPLE
    ```powershell
    New-MtGraphFixture -Path ./powershell/tests/fixtures/graph-replay -Scenario badly-configured `
        -Uri 'v1.0/directory/onPremisesSynchronization' `
        -Response @{ value = @(@{ id = 'fa4efa4e-0000-0000-0000-000000000001'; features = @{ blockSoftMatchEnabled = $false } }) }
    ```

    Writes the response a badly configured tenant gives for its on-premises synchronization settings.

    .EXAMPLE
    ```powershell
    New-MtGraphFixture -Path ./fixtures -Scenario no-permission -Uri 'v1.0/directory/onPremisesSynchronization' -StatusCode 403 `
        -Response @{ error = @{ code = 'Authorization_RequestDenied'; message = 'Insufficient privileges to complete the operation.' } }
    ```

    Writes a 403 response, so a test can show how it handles a missing permission.

    .LINK
    https://maester.dev/docs/commands/New-MtGraphFixture
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9][a-z0-9.-]*$')]
        [string] $Scenario,

        [Parameter(Mandatory)]
        [string] $Uri,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [string] $Method = 'GET',

        [Parameter()]
        [AllowNull()]
        [object] $Body,

        [Parameter()]
        [AllowNull()]
        [object] $Response,

        [Parameter()]
        [ValidateRange(100, 599)]
        [int] $StatusCode = 200,

        [Parameter()]
        [string] $Note
    )

    $toNode = {
        param($value)
        if ($null -eq $value) { return $null }
        # A hashtable's order changes from one PowerShell process to the next: sort it so the file does not.
        $text = if ($value -is [string]) { $value } else { ConvertTo-MtGraphFixtureJson -Json (ConvertTo-Json -InputObject $value -Depth 50) -Sort }
        , [System.Text.Json.Nodes.JsonNode]::Parse($text)
    }

    $root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $folder = Join-Path $root $Scenario
    $bodyNode = & $toNode $Body
    $responseNode = & $toNode $Response
    $key = Get-MtGraphFixtureKey -Uri $Uri -Method $Method -Body $(if ($null -ne $bodyNode) { $bodyNode.ToJsonString() } else { $null })

    $target = Join-Path (Join-Path $folder 'graph') $key.FileName
    Write-Verbose "Graph fixture for '$($key.Key)': $target"
    if ($PSCmdlet.ShouldProcess($target, "Write the Graph fixture for '$($key.Key)'")) {
        $file = Save-MtGraphFixture -Folder $folder -KeyInfo $key -Status $StatusCode -Body $responseNode -RequestBody $bodyNode -Note $Note
        $null = Update-MtGraphFixtureIndex -Path $root -Scenario $Scenario
        Get-Item -LiteralPath $file
    }
}
