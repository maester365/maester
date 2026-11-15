function Update-MtGraphFixtureIndex {
    <#
    .SYNOPSIS
    Writes the index.json of a Graph fixture set, and checks that every fixture file is named after its request.

    .DESCRIPTION
    index.json lists every request a fixture set answers, sorted by key, with its file and HTTP status, so a person
    can find the fixture for a request. Recording and New-MtGraphFixture keep it up to date; run this after you
    copy, rename or delete fixture files by hand.

    Each file's key is worked out again from the request it stores. A file whose name or stored key does not match
    is reported as an error, because replay looks files up by name and would never use it.

    .PARAMETER Path
    The folder that holds the fixture sets.

    .PARAMETER Scenario
    The fixture set. Without it, every fixture set under -Path is indexed.

    .EXAMPLE
    Update-MtGraphFixtureIndex -Path ./powershell/tests/fixtures/graph-replay

    Rewrites the index of every fixture set that ships with the unit tests.

    .LINK
    https://maester.dev/docs/commands/Update-MtGraphFixtureIndex
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [string] $Scenario
    )

    $root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $folders = if ($Scenario) { @(Join-Path $root $Scenario) } else { @(Get-ChildItem -LiteralPath $root -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'graph') } | ForEach-Object FullName) }

    foreach ($folder in $folders) {
        $graphFolder = Join-Path $folder 'graph'
        Write-Verbose "Indexing the Graph fixture set '$folder'."
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            Write-Warning "There is no Graph fixture set at '$folder'."
            continue
        }
        $entries = [System.Collections.Generic.List[object]]::new()
        $problems = [System.Collections.Generic.List[string]]::new()
        foreach ($file in @(Get-ChildItem -LiteralPath $graphFolder -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
            try {
                $document = [System.Text.Json.Nodes.JsonNode]::Parse([System.IO.File]::ReadAllText($file.FullName))
                $request = $document['request']
                $body = if ($null -ne $request['body']) { $request['body'].ToJsonString() } else { $null }
                $key = Get-MtGraphFixtureKey -Uri ($request['uri'].GetValue[string]()) -Method ($request['method'].GetValue[string]()) -Body $body
                $storedKey = if ($null -ne $request['key']) { $request['key'].GetValue[string]() } else { $null }
                if ($storedKey -cne $key.Key) { $problems.Add("graph/$($file.Name): stores the key '$storedKey', but its request gives '$($key.Key)'.") }
                if ($file.Name -cne $key.FileName) { $problems.Add("graph/$($file.Name): should be named '$($key.FileName)' for '$($key.Key)'.") }
                $status = if ($null -ne $document['response']['status']) { $document['response']['status'].GetValue[int]() } else { 200 }
                $entries.Add([pscustomobject]@{ key = $key.Key; file = "graph/$($file.Name)"; status = $status })
            } catch {
                $problems.Add("graph/$($file.Name): is not a fixture file ($($_.Exception.Message)).")
            }
        }

        [object[]] $sorted = $entries.ToArray()
        [System.Array]::Sort($sorted, [System.Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.key, $b.key) })
        $index = [ordered]@{ scenario = (Split-Path $folder -Leaf); fixtures = @($sorted) }
        $json = (ConvertTo-MtGraphFixtureJson -Json (ConvertTo-Json -InputObject $index -Depth 5)) + "`n"
        $indexFile = Join-Path $folder 'index.json'
        if ($PSCmdlet.ShouldProcess($indexFile, 'Write the Graph fixture index')) {
            [System.IO.File]::WriteAllText($indexFile, $json, [System.Text.UTF8Encoding]::new($false))
        }
        foreach ($problem in $problems) { Write-Error -Message "Graph fixture set '$folder': $problem" }

        [pscustomobject]@{
            PSTypeName = 'Maester.GraphFixtureIndex'
            Scenario   = Split-Path $folder -Leaf
            Folder     = $folder
            Count      = $sorted.Count
            Problems   = @($problems)
        }
    }
}
