function Read-MtGraphFixture {
    <#
    .SYNOPSIS
    Internal: Reads the fixture of one Graph request from a fixture set, or returns $null when it has none.

    .DESCRIPTION
    The file is found by the file name of the key (Get-MtGraphFixtureKey). A file whose stored key is not the key
    asked for is not used: it was renamed or edited by hand, and Update-MtGraphFixtureIndex reports it.

    .EXAMPLE
    Read-MtGraphFixture -Folder ./fixtures/default -KeyInfo (Get-MtGraphFixtureKey -Uri 'v1.0/organization')

    Returns Status, Body (JSON text, or $null for an empty body) and File.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The folder of the fixture set (scenario).
        [Parameter(Mandatory)]
        [string] $Folder,

        # The key of the request, from Get-MtGraphFixtureKey.
        [Parameter(Mandatory)]
        [object] $KeyInfo
    )

    $file = Join-Path (Join-Path $Folder 'graph') $KeyInfo.FileName
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return $null }

    $document = [System.Text.Json.Nodes.JsonNode]::Parse([System.IO.File]::ReadAllText($file))
    $storedKey = if ($null -ne $document['request'] -and $null -ne $document['request']['key']) { $document['request']['key'].GetValue[string]() } else { $null }
    if ($storedKey -cne $KeyInfo.Key) {
        Write-Warning "The Graph fixture '$file' is for '$storedKey', not '$($KeyInfo.Key)'. Run Update-MtGraphFixtureIndex to find fixtures whose file name does not match their request."
        return $null
    }

    $response = $document['response']
    $status = if ($null -ne $response -and $null -ne $response['status']) { $response['status'].GetValue[int]() } else { 200 }
    $body = if ($null -ne $response -and $null -ne $response['body']) { $response['body'].ToJsonString() } else { $null }
    [pscustomobject]@{
        Status = $status
        Body   = $body
        File   = $file
    }
}
