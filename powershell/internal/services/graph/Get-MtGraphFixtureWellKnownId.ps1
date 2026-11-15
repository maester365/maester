function Get-MtGraphFixtureWellKnownId {
    <#
    .SYNOPSIS
    Internal: Returns the GUIDs that Graph fixture sanitisation keeps, because Maester compares data with them.

    .DESCRIPTION
    Sanitisation replaces every GUID in a recorded response with a fake one, except the GUIDs that are the same in
    every tenant and that checks look for: role template IDs (62e90394-... is Global Administrator), Microsoft
    application and permission IDs, licence SKU and service plan IDs, and the like. Replacing those would make a
    replayed test take another branch than it did against the tenant.

    The list is every GUID written in Maester's own source: the module's PowerShell files and assets, and the
    built-in tests. A GUID a check compares with is in the source by definition. The unit tests under the module's
    tests folder are not read. The list is read once per session.

    .EXAMPLE
    Get-MtGraphFixtureWellKnownId

    Returns a case-insensitive set of GUID strings.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.HashSet[string]])]
    param()

    if ($script:__MtGraphFixtureWellKnownIds) { return , $script:__MtGraphFixtureWellKnownIds }

    $ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    # The all-zero GUID marks "none" in many Graph properties.
    $null = $ids.Add('00000000-0000-0000-0000-000000000000')
    $pattern = [regex]::new('(?<![0-9A-Fa-f])[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}(?![0-9A-Fa-f])')

    $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
    $unitTests = (Join-Path $moduleBase 'tests') + [System.IO.Path]::DirectorySeparatorChar
    $roots = @($moduleBase, (Get-MtMaesterTestFolderPath)) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique
    foreach ($root in $roots) {
        $files = Get-ChildItem -LiteralPath $root -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1', '*.json' -ErrorAction SilentlyContinue |
            Where-Object { -not $_.FullName.StartsWith($unitTests, [System.StringComparison]::OrdinalIgnoreCase) }
        foreach ($file in $files) {
            foreach ($match in $pattern.Matches([System.IO.File]::ReadAllText($file.FullName))) { $null = $ids.Add($match.Value) }
        }
    }

    $script:__MtGraphFixtureWellKnownIds = $ids
    return , $ids
}
