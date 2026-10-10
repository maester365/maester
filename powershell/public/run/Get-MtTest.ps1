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

    .PARAMETER Product
    Only tests of these products: keys such as entra, or an alias such as 'Entra ID'. Matches a test's
    Product or any of its RelatedProduct values. '*' wildcards are allowed.

    .PARAMETER Feature
    Only tests about these features of a product, for example conditional-access.

    .PARAMETER Area
    Only tests of these security areas, for example authentication.

    .PARAMETER Severity
    Only tests with these severities: Critical, High, Medium, Low or Info.

    .PARAMETER Suite
    Only tests of these suites, for example Maester, CISA or AD.

    .PARAMETER Path
    A Test.<ID>.ps1 file or a folder of them to validate.

    .EXAMPLE
    Get-MtTest -Product entra -Severity High | Format-Table Id, Title, Feature, Area

    Lists the built-in Entra ID tests of high severity. The values of one selector are alternatives; different
    selectors must all match.

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
        [string[]] $Product,

        [Parameter()]
        [string[]] $Feature,

        [Parameter()]
        [string[]] $Area,

        [Parameter()]
        [string[]] $Severity,

        [Parameter()]
        [string[]] $Suite,

        [Parameter()]
        [string] $Path
    )

    Write-Verbose "Get-MtTest: Id=$($Id -join ', ') Tag=$($Tag -join ', ') Path=$Path"
    $tests = if ($Path) {
        if (-not (Test-Path -LiteralPath $Path)) { Write-Error "The path '$Path' does not exist."; return }
        $root = if (Test-Path -LiteralPath $Path -PathType Container) { (Resolve-Path -LiteralPath $Path).Path } else { Split-Path (Resolve-Path -LiteralPath $Path).Path -Parent }
        @(Get-MtNativeTestInventory -Path $Path -Root $root)
    } else {
        @(Get-MtTestCatalog)
    }
    # The typed selectors, with the same matching as Invoke-Maester.
    $selection = Resolve-MtSelection -RunConfig ([pscustomobject]@{ Selection = [pscustomobject]@{} }) -Product $Product -Feature $Feature -Area $Area -Severity $Severity -Suite $Suite
    $selectorInUse = Test-MtSelectorInUse -Selection $selection
    foreach ($t in $tests) {
        if ($Id -and -not (Test-MtIdMatch -Id $t.Id -Pattern $Id)) { continue }
        if ($Tag -and -not (@($t.EffectiveTag) | Where-Object { $tg = $_; $Tag | Where-Object { $tg -like $_ } })) { continue }
        if ($selectorInUse -and (Test-MtSelectorMatch -Selection $selection -Product (@($t.Product) + @($t.RelatedProduct)) -Feature $t.Feature -Area $t.Area -Severity $t.Severity -Suite $t.Suite)) { continue }
        $copy = [ordered]@{}
        foreach ($p in $t.PSObject.Properties) { $copy[$p.Name] = $p.Value }
        $copy.IsValid = -not ($t.Errors -and $t.Errors.Count -gt 0)
        $copy.PSTypeName = 'Maester.Test'
        [pscustomobject]$copy
    }
}
