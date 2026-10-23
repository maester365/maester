function Test-MtBuiltInPackCode {
    <#
    .SYNOPSIS
    Returns $true when Code is the code of a pack that ships with Maester and Path is inside that pack.

    .DESCRIPTION
    A pack that ships with Maester may name a test family by its bare code (ZTA for the Zero Trust
    Assessment pack), which the test ID grammar would otherwise reject because it has no digit or separator.
    The exception holds only for a file inside that pack's folder, so a custom test cannot use the bare code.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Code,

        [Parameter(Mandatory)]
        [string] $Path
    )

    $full = [System.IO.Path]::GetFullPath($Path)
    foreach ($pack in @(Get-MtBuiltInPack)) {
        if (-not $pack.Manifest -or -not $pack.Manifest.Code -or -not ([string]$pack.Manifest.Code).Equals($Code, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $root = [System.IO.Path]::GetFullPath($pack.Root).TrimEnd('/', '\') + [System.IO.Path]::DirectorySeparatorChar
        if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    $false
}
