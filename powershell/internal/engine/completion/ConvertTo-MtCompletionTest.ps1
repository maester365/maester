function ConvertTo-MtCompletionTest {
    <#
    .SYNOPSIS
    Keeps what Tab completion uses of test rows: the catalogue, a custom test inventory or a pack's test list.

    .DESCRIPTION
    Each row has Id, Title, Product, RelatedProduct, Feature, Area, Severity, Suite, Control (the references and
    the requirement IDs alone, so MS.AAD.3.1 finds the test mapped to cisa-scuba:MS.AAD.3.1), Lifecycle,
    LongRunning, IsFamily, Tags (what -Tag matches, without the test's ID: its own tags, its suite's and, for a
    built-in test, its Maester 2.x tags), Source (BuiltIn, Custom or Pack), Pack, SortKey (the ID with its
    numbers padded, so MT.1005 sorts before MT.1010) and Candidate (filled in by Get-MtCompletionCandidate the
    first time the test is listed). Rows without an Id are dropped. One call takes all the rows, with plain
    loops: completion has to be fast.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Test,
        [Parameter(Mandatory)] [ValidateSet('BuiltIn', 'Custom', 'Pack')] [string] $Source,
        # The pack the rows come from.
        [Parameter()] [string] $Pack
    )

    $legacy = if ($Source -eq 'BuiltIn') { (Get-MtLegacyTagTable).ByTest } else { $null }
    foreach ($t in $Test) {
        if ($null -eq $t -or -not $t.Id) { continue }
        $id = [string]$t.Id
        $tags = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($tag in @($t.Tag) + @($t.SuiteTag)) { if ($tag) { $null = $tags.Add([string]$tag) } }
        $old = $null
        if ($legacy -and $legacy.TryGetValue($id, [ref] $old)) { foreach ($tag in $old) { $null = $tags.Add([string]$tag) } }
        $control = [System.Collections.Generic.List[string]]::new()
        foreach ($reference in @($t.Control)) {
            if (-not $reference) { continue }
            $control.Add([string]$reference)
            $colon = ([string]$reference).IndexOf(':')
            if ($colon -gt 0) { $control.Add(([string]$reference).Substring($colon + 1)) }
        }
        $related = [System.Collections.Generic.List[string]]::new()
        foreach ($product in @($t.RelatedProduct)) { if ($product) { $related.Add([string]$product) } }
        [pscustomobject]@{
            Id             = $id
            Title          = [string]$t.Title
            Product        = [string]$t.Product
            RelatedProduct = $related.ToArray()
            Feature        = [string]$t.Feature
            Area           = [string]$t.Area
            Severity       = [string]$t.Severity
            Suite          = [string]$t.Suite
            Control        = $control.ToArray()
            Lifecycle      = [string]$t.Lifecycle
            LongRunning    = [bool]$t.LongRunning
            IsFamily       = [bool]$t.InstanceSource
            Tags           = [string[]]@($tags)
            Source         = $Source
            Pack           = $Pack
            # Each number padded to 10 digits, with two plain replacements: a script block evaluator is slow.
            SortKey        = ($id -replace '\d+', '0000000000$0') -replace '(?<!\d)\d*(\d{10})(?!\d)', '$1'
            Candidate      = $null
        }
    }
}
