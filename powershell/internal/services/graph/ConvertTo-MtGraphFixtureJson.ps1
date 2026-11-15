function ConvertTo-MtGraphFixtureJson {
    <#
    .SYNOPSIS
    Internal: Writes JSON for Graph fixtures: indented or compact, optionally with sorted members.

    .DESCRIPTION
    Fixture files are read by people and compared in pull requests, so they are written the same way every time:
    two-space indentation, LF line endings, readable characters (no \u escapes for accents) and a final newline.
    -Sort orders the members of every object by name (ordinal). The fixture key hashes a body written with
    -Compress -Sort, so a body built from a hashtable, whose order changes from one process to the next, always
    gets the same key.

    Text that is not JSON is returned trimmed, so a body that is not JSON still gets a stable key.

    The JSON is handled with System.Text.Json nodes rather than ConvertFrom-Json, which would turn date strings
    into DateTime values and write them back in another format.

    .EXAMPLE
    ConvertTo-MtGraphFixtureJson -Json '{"b":1,"a":2}' -Compress -Sort

    Returns {"a":2,"b":1}.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Json')]
    [OutputType([string])]
    param(
        # JSON text.
        [Parameter(Mandatory, ParameterSetName = 'Json')]
        [AllowEmptyString()]
        [string] $Json,

        # A parsed JSON node. It is not changed.
        [Parameter(Mandatory, ParameterSetName = 'Node')]
        [AllowNull()]
        [System.Text.Json.Nodes.JsonNode] $Node,

        # Write without indentation or line breaks.
        [Parameter()]
        [switch] $Compress,

        # Sort the members of every object by name.
        [Parameter()]
        [switch] $Sort
    )

    if ($PSCmdlet.ParameterSetName -eq 'Json') {
        if ([string]::IsNullOrWhiteSpace($Json)) { return '' }
        try {
            $Node = [System.Text.Json.Nodes.JsonNode]::Parse($Json)
        } catch {
            return $Json.Trim()
        }
    } elseif ($null -ne $Node) {
        $Node = $Node.DeepClone()
    }
    if ($null -eq $Node) { return 'null' }

    if ($Sort) {
        $sortNode = {
            param($current)
            if ($current -is [System.Text.Json.Nodes.JsonObject]) {
                [string[]] $names = @(foreach ($member in $current) { $member.Key })
                [System.Array]::Sort($names, [System.StringComparer]::Ordinal)
                $sorted = [System.Text.Json.Nodes.JsonObject]::new()
                foreach ($name in $names) {
                    $child = $current[$name]
                    $null = $current.Remove($name)
                    $sorted.Add($name, (& $sortNode $child))
                }
                return , $sorted
            }
            if ($current -is [System.Text.Json.Nodes.JsonArray]) {
                $items = @(foreach ($item in $current) { , $item })
                $current.Clear()
                foreach ($item in $items) { $current.Add((& $sortNode $item)) }
                return , $current
            }
            return , $current
        }
        $Node = & $sortNode $Node
    }

    $options = [System.Text.Json.JsonSerializerOptions]::new()
    $options.WriteIndented = -not $Compress
    $options.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
    # .NET 8 indents with the platform's line break; fixtures are always LF.
    return $Node.ToJsonString($options) -replace "`r`n", "`n"
}
