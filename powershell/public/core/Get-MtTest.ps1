function Get-MtTest {
    <#
    .SYNOPSIS
    Lists Maester native tests and their metadata without connecting to a tenant.

    .DESCRIPTION
    Without -Path, returns the tests that ship with Maester (the catalog). With -Path, reads the native
    tests (Test.<ID>.ps1) in a file or folder and validates them; each object's Errors property lists
    every problem with its line, and IsValid is $false when there is one. No test code is run.

    .PARAMETER Id
    Only tests with these IDs: exact IDs or '*' wildcards.

    .PARAMETER Tag
    Only tests that carry any of these tags.

    .PARAMETER Path
    A Test.<ID>.ps1 file or a folder of them to validate.

    .EXAMPLE
    Get-MtTest -Tag CA | Format-Table Id, Title, Severity

    Lists the built-in Conditional Access tests.

    .EXAMPLE
    Get-MtTest -Path ./Custom | Where-Object { -not $_.IsValid } | Select-Object -ExpandProperty Errors

    Shows every problem in the custom tests.

    .LINK
    https://maester.dev/docs/commands/Get-MtTest
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string[]] $Id,

        [Parameter()]
        [string[]] $Tag,

        [Parameter()]
        [string] $Path
    )

    $tests = if ($Path) {
        if (-not (Test-Path -LiteralPath $Path)) { Write-Error "The path '$Path' does not exist."; return }
        $root = if (Test-Path -LiteralPath $Path -PathType Container) { (Resolve-Path -LiteralPath $Path).Path } else { Split-Path (Resolve-Path -LiteralPath $Path).Path -Parent }
        @(Get-MtNativeTestInventory -Path $Path -Root $root)
    } else {
        @(Get-MtTestCatalog)
    }
    foreach ($t in $tests) {
        if ($Id -and -not (Test-MtIdMatch -Id $t.Id -Pattern $Id)) { continue }
        if ($Tag -and -not (@($t.EffectiveTag) | Where-Object { $tg = $_; $Tag | Where-Object { $tg -like $_ } })) { continue }
        $copy = [ordered]@{}
        foreach ($p in $t.PSObject.Properties) { $copy[$p.Name] = $p.Value }
        $copy.IsValid = -not ($t.Errors -and $t.Errors.Count -gt 0)
        $copy.PSTypeName = 'Maester.Test'
        [pscustomobject]$copy
    }
}
