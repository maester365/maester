function Read-MtZtaWorkshopFile {
    <#
    .SYNOPSIS
    Reads a JSON file of the pack's workshop folder, or returns $null when it is not there.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The file. An empty path returns $null.
        [Parameter()] [AllowEmptyString()] [string] $Path
    )

    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -Depth 20
}
