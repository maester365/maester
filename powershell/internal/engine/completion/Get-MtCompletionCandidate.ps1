function Get-MtCompletionCandidate {
    <#
    .SYNOPSIS
    Lists the values of one kind of parameter for Tab completion, in the order they should be shown.

    .DESCRIPTION
    Each candidate has Value (what is inserted), Match (other names the word may start with: aliases, display
    names, the requirements a test implements), Search (more text a search word may appear in), ListItem,
    ToolTip and Order. Get-MtArgumentCompletion filters and ranks them by the word.

    The selector kinds (Product, Feature, Area, Severity, Suite, Tag, TestId) read the tests the command line is
    about (Get-MtCompletionTestSet). When another selector is on the line, only values that still select a test
    are listed, since selectors combine with AND; otherwise every key the taxonomy has is listed. The tooltip
    gives the number of tests. The Taxonomy* kinds list the taxonomy's keys alone, for writing a test.

    Kinds: Product, TaxonomyProduct, Feature, TaxonomyFeature, Area, TaxonomyArea, Severity, Suite, Tag, TestId,
    Pack, PackId, InstalledPackId, Service, TestService, ResourceType, Mitre, Setting and Role.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Kind,
        [Parameter(Mandatory)] [string] $CommandName,
        # The word being completed, without quotes. Used by TestId for its wildcard groups.
        [Parameter()] [AllowEmptyString()] [string] $Word = '',
        # The other parameters on the command line.
        [Parameter()] [AllowNull()] [hashtable] $BoundParameters = @{},
        # The command's own values, for the Service kind.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [string[]] $Value = @()
    )

    if (-not $BoundParameters) { $BoundParameters = @{} }
    $candidate = {
        param([string] $Value, [double] $Order, [string] $ToolTip, [string] $ListItem, [string[]] $Match = @(), [string] $Search = '')
        [pscustomobject]@{ Value = $Value; Order = $Order; ToolTip = $ToolTip; ListItem = $(if ($ListItem) { $ListItem } else { $Value }); Match = $Match; Search = $Search }
    }
    $label = {
        param([string] $Key, [string] $Name)
        if ($Name -and $Name -ne $Key) { "$Key - $Name" } else { $Key }
    }
    $countText = {
        param([int] $Count, [bool] $Narrowed)
        $tests = if ($Count -eq 1) { '1 test' } else { "$Count tests" }
        if ($Narrowed) { "$tests with the other parameters on the line." } else { "$tests." }
    }
    # Number of tests for each value a test has, case-insensitively.
    $tally = {
        param($Tests, [scriptblock] $Of)
        $counts = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($t in $Tests) {
            foreach ($v in @(& $Of $t)) {
                if (-not $v) { continue }
                $n = 0
                $null = $counts.TryGetValue([string]$v, [ref] $n)
                $counts[[string]$v] = $n + 1
            }
        }
        $counts
    }
    $countOf = {
        param($Counts, [string] $Key)
        $n = 0
        $null = $Counts.TryGetValue($Key, [ref] $n)
        $n
    }
    $strings = {
        param($Name)
        foreach ($item in @($BoundParameters[$Name])) { if ($null -ne $item -and [string]$item -ne '') { [string]$item } }
    }
    $testSetFor = @{ CommandName = $CommandName; BoundParameters = $BoundParameters }
    $testSet = { Get-MtCompletionTestSet @testSetFor }

    switch -Exact ($Kind) {
        { $_ -in 'Product', 'TaxonomyProduct' } {
            $taxonomy = Get-MtTaxonomy
            $set = if ($Kind -eq 'Product') { & $testSet } else { $null }
            $counts = if ($set) { & $tally $set.Tests { param($t) @($t.Product) + @($t.RelatedProduct) } } else { $null }
            $order = 0
            foreach ($p in $taxonomy.Products) {
                $order++
                $n = if ($counts) { & $countOf $counts $p.Key } else { 0 }
                if ($set -and $set.Narrowed -and $n -eq 0) { continue }
                $aliases = @($p.Aliases | Where-Object { $_ -and $_ -ne $p.Name })
                $tip = @($p.Name)
                if ($aliases.Count -gt 0) { $tip += "Also: $($aliases -join ', ')" }
                if ($set) { $tip += & $countText $n $set.Narrowed }
                & $candidate $p.Key $order ($tip -join "`n") (& $label $p.Key $p.Name) (@($p.Name) + $aliases)
            }
            if ($counts) {
                # The products of custom and pack tests that the taxonomy does not have.
                foreach ($key in ($counts.Keys | Sort-Object)) {
                    if ($taxonomy.Lookup.Product.ContainsKey($key)) { continue }
                    & $candidate $key (1000 + $order++) ("A product of custom or pack tests.`n" + (& $countText $counts[$key] $set.Narrowed))
                }
            }
        }

        { $_ -in 'Feature', 'TaxonomyFeature' } {
            $taxonomy = Get-MtTaxonomy
            # The features of the products on the line, by key or alias, '*' wildcards allowed.
            $productPatterns = @(& $strings 'Product' | ForEach-Object { if ($_.Contains('*')) { $_ } else { $k = Resolve-MtProductKey -Name $_ -Taxonomy $taxonomy; if ($k) { $k } else { $_ } } })
            $features = [ordered]@{}
            foreach ($p in $taxonomy.Products) {
                if ($productPatterns.Count -gt 0 -and -not ($productPatterns | Where-Object { $p.Key -like $_ })) { continue }
                foreach ($f in @($p.Features)) {
                    if (-not $features.Contains($f.Key)) { $features[$f.Key] = [pscustomobject]@{ Name = $f.Name; Products = [System.Collections.Generic.List[string]]::new() } }
                    $features[$f.Key].Products.Add($p.Name)
                }
            }
            $set = if ($Kind -eq 'Feature') { & $testSet } else { $null }
            $counts = if ($set) { & $tally $set.Tests { param($t) $t.Feature } } else { $null }
            $order = 0
            foreach ($key in $features.Keys) {
                $order++
                $f = $features[$key]
                $n = if ($counts) { & $countOf $counts $key } else { 0 }
                if ($set -and $set.Narrowed -and $n -eq 0) { continue }
                $tip = @("$($f.Name) ($($f.Products -join ', '))")
                if ($set) { $tip += & $countText $n $set.Narrowed }
                & $candidate $key $order ($tip -join "`n") (& $label $key $f.Name) @($f.Name) ($f.Products -join ' ')
            }
            if ($counts) {
                # The features of custom and pack tests that the taxonomy does not have.
                $known = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($p in $taxonomy.Products) { foreach ($f in @($p.Features)) { $null = $known.Add($f.Key) } }
                foreach ($key in ($counts.Keys | Sort-Object)) {
                    if ($known.Contains($key)) { continue }
                    & $candidate $key (1000 + $order++) ("A feature of custom or pack tests.`n" + (& $countText $counts[$key] $set.Narrowed))
                }
            }
        }

        { $_ -in 'Area', 'TaxonomyArea' } {
            $taxonomy = Get-MtTaxonomy
            $set = if ($Kind -eq 'Area') { & $testSet } else { $null }
            $counts = if ($set) { & $tally $set.Tests { param($t) $t.Area } } else { $null }
            $order = 0
            foreach ($a in $taxonomy.Areas) {
                $order++
                $n = if ($counts) { & $countOf $counts $a.Key } else { 0 }
                if ($set -and $set.Narrowed -and $n -eq 0) { continue }
                $tip = @("$($a.Name): $($a.Description)")
                if ($set) { $tip += & $countText $n $set.Narrowed }
                & $candidate $a.Key $order ($tip -join "`n") (& $label $a.Key $a.Name) @($a.Name) $a.Description
            }
            if ($counts) {
                foreach ($key in ($counts.Keys | Sort-Object)) {
                    if ($taxonomy.Lookup.Area.ContainsKey($key)) { continue }
                    & $candidate $key (1000 + $order++) ("An area of custom or pack tests.`n" + (& $countText $counts[$key] $set.Narrowed))
                }
            }
        }

        'Severity' {
            $set = & $testSet
            $counts = & $tally $set.Tests { param($t) $t.Severity }
            $order = 0
            foreach ($severity in 'Critical', 'High', 'Medium', 'Low', 'Info') {
                $order++
                $n = & $countOf $counts $severity
                if ($set.Narrowed -and $n -eq 0) { continue }
                & $candidate $severity $order (& $countText $n $set.Narrowed)
            }
        }

        'Suite' {
            $index = Get-MtCompletionIndex
            $set = & $testSet
            $counts = & $tally $set.Tests { param($t) $t.Suite }
            $order = 0
            foreach ($key in ($counts.Keys | Sort-Object)) {
                $name = $null
                $null = $index.Suites.TryGetValue($key, [ref] $name)
                $tip = @($(if ($name) { $name } else { $key })) + @(& $countText $counts[$key] $set.Narrowed)
                & $candidate $key (++$order) ($tip -join "`n") (& $label $key $name) @($(if ($name) { $name }))
            }
        }

        'Tag' {
            $replacement = (Get-MtLegacyTagTable).Replacement
            $set = & $testSet
            $counts = & $tally $set.Tests { param($t) $t.Tags }
            $order = 0
            foreach ($key in ($counts.Keys | Sort-Object)) {
                $tip = @(& $countText $counts[$key] $set.Narrowed)
                $instead = $null
                if ($replacement.TryGetValue($key, [ref] $instead)) { $tip += "A Maester 2.x tag: $instead selects the same tests." }
                & $candidate $key (++$order) ($tip -join "`n")
            }
        }

        'TestId' {
            $taxonomy = Get-MtTaxonomy
            # Natural order (MT.1005 before MT.1010), sorted ordinally: a culture sort ignores the hyphens of AD-DACL-16.
            # The generic overload: with the plain one, PowerShell passes a copy of the items and only the keys get sorted.
            [object[]] $sorted = @((& $testSet).Tests)
            $keys = [string[]]@(foreach ($t in $sorted) { $t.SortKey })
            [System.Array]::Sort[string, object]($keys, $sorted, [System.StringComparer]::OrdinalIgnoreCase)

            if ($Word -and $Word.IndexOfAny([char[]]'*?') -lt 0) {
                # The next segment of the IDs that start with the word, as a wildcard: CISA.MS. offers CISA.MS.AAD.*.
                $groups = [ordered]@{}
                foreach ($t in $sorted) {
                    if (-not $t.Id.StartsWith($Word, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                    $end = $t.Id.IndexOfAny([char[]]'.-', $Word.Length)
                    if ($end -lt 0) { continue }
                    $prefix = $t.Id.Substring(0, $end + 1)
                    $groups[$prefix] = 1 + [int]$groups[$prefix]
                }
                $order = -100000
                foreach ($prefix in $groups.Keys) {
                    if ($groups[$prefix] -lt 2) { continue }
                    & $candidate "$prefix*" ($order++) "The $($groups[$prefix]) tests whose ID starts with $prefix"
                }
            }

            $order = 0
            foreach ($t in $sorted) {
                $order++
                # A test's candidates are made once and kept on its row (the rows are cached); only the order changes.
                if (-not $t.Candidate) {
                    $productName = $t.Product
                    $featureName = $t.Feature
                    $entry = $null
                    if ($t.Product -and $taxonomy.Lookup.Product.TryGetValue($t.Product, [ref] $entry)) {
                        $productName = $entry.Name
                        $feature = $null
                        if ($t.Feature -and $taxonomy.Lookup.Feature[$entry.Key].TryGetValue($t.Feature, [ref] $feature)) { $featureName = $feature.Name }
                    }
                    # Plain statements, no pipelines: the first Tab makes this for every test.
                    $tip = [System.Collections.Generic.List[string]]::new()
                    if ($t.Title) { $tip.Add($t.Title) }
                    $about = [System.Collections.Generic.List[string]]::new()
                    if ($productName -and $featureName) { $about.Add("$productName > $featureName") } elseif ($productName) { $about.Add($productName) }
                    if ($t.Severity) { $about.Add($t.Severity) }
                    if ($t.Suite) { $about.Add($t.Suite) }
                    if ($about.Count -gt 0) { $tip.Add($about -join ' | ') }
                    foreach ($reference in $t.Control) { if ($reference.Contains(':')) { $tip.Add("Implements $reference"); break } }
                    if ($t.Lifecycle -and $t.Lifecycle -ne 'Stable') { $tip.Add("$($t.Lifecycle) test: runs when named by its ID.") }
                    if ($t.LongRunning) { $tip.Add('Long-running test: runs when named by its ID.') }
                    if ($t.Source -eq 'Custom') { $tip.Add('Custom test.') }
                    if ($t.Source -eq 'Pack') { $tip.Add("Test of the pack $($t.Pack).") }
                    $title = if ($t.Title.Length -gt 70) { $t.Title.Substring(0, 69) + [char]0x2026 } else { $t.Title }
                    $item = if ($title) { "$($t.Id)  $title" } else { $t.Id }
                    $t.Candidate = @(
                        & $candidate $t.Id 0 ($tip -join "`n") $item $t.Control "$($t.Title) $productName $featureName"
                        if ($t.IsFamily) { & $candidate "$($t.Id).*" 0 "Every instance of $($t.Id): $($t.Title)`nThe instances are known only when the test runs." }
                    )
                }
                $t.Candidate[0].Order = $order
                $t.Candidate[0]
                if ($t.Candidate.Count -gt 1) { $t.Candidate[1].Order = $order + 0.5; $t.Candidate[1] }
            }
        }

        { $_ -in 'Pack', 'PackId', 'InstalledPackId' } {
            $packs = @(Read-MtPackList -PackLock ([string]$BoundParameters['PackLock']) -Path ([string]$BoundParameters['Path']))
            if ($Kind -eq 'InstalledPackId') { $packs = @($packs | Where-Object { $_.Installed -and -not $_.BuiltIn }) }
            $order = 0
            foreach ($pack in $packs) {
                $order++
                $tip = @("$($pack.Name) $($pack.Version)".Trim())
                if ($pack.Publisher) { $tip += "Publisher: $($pack.Publisher)" }
                $tip += if ($pack.BuiltIn) { 'Ships with Maester.' } else { 'Installed.' }
                $count = @($pack.Tests).Count
                if ($count -gt 0) { $tip += & $countText $count $false }
                if ($Kind -eq 'Pack' -and $pack.Code) {
                    & $candidate $pack.Code $order ($tip -join "`n") (& $label $pack.Code $pack.Name) @($pack.Id, $pack.Name)
                }
                & $candidate $pack.Id (1000 + $order) ($tip -join "`n") (& $label $pack.Id $pack.Name) @($pack.Code, $pack.Name)
            }
        }

        'Service' {
            $order = 0
            $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($name in $Value) {
                if ($seen.Add($name)) { & $candidate $name (++$order) $(if ($name -eq 'All') { 'Every Microsoft 365 service.' } else { "The $name service." }) }
            }
            # The services of pack connectors: those this session registered, and those the packs declare.
            $registry = (Get-MtServiceRegistry).Services
            foreach ($name in ($registry.Keys | Sort-Object)) {
                if ($registry[$name].ContainsKey('Pack') -and $seen.Add($name)) { & $candidate $name (1000 + ++$order) "The $name service of the pack $($registry[$name].Pack.Id)." }
            }
            foreach ($pack in @(Read-MtPackList)) {
                foreach ($name in $pack.Services) { if ($name -and $seen.Add($name)) { & $candidate $name (1000 + ++$order) "The $name service of the pack $($pack.Id)." } }
            }
        }

        'TestService' {
            $order = 0
            $services = (Get-MtServiceRegistry -BuiltInOnly).Services
            foreach ($name in ($services.Keys | Sort-Object)) {
                $aliases = @($services[$name].Aliases | Where-Object { $_ })
                $tip = if ($aliases.Count -gt 0) { "The $name service. Also: $($aliases -join ', ')" } else { "The $name service." }
                & $candidate $name (++$order) $tip $null $aliases
            }
        }

        'ResourceType' {
            $order = 0
            foreach ($type in (Get-MtTaxonomy).ResourceTypes) { & $candidate $type.Key (++$order) $type.Description $null @() $type.Description }
        }

        'Mitre' {
            $attack = Get-MtAttackData
            $order = 0
            foreach ($technique in $attack.TechniqueList) {
                if ($attack.Retired.Contains([string]$technique.Id)) { continue }
                & $candidate $technique.Id (++$order) "$($technique.Name) (MITRE ATT&CK $($attack.Version))" (& $label $technique.Id $technique.Name) @($technique.Name)
            }
            & $candidate 'None' (++$order) 'The test addresses no ATT&CK technique.'
        }

        'Setting' {
            if (-not $script:__MtSettingsRegistry) {
                $script:__MtSettingsRegistry = Import-PowerShellDataFile -Path (Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterSettings.psd1')
            }
            $settings = $script:__MtSettingsRegistry.Settings
            $order = 0
            foreach ($name in ($settings.Keys | Sort-Object)) { & $candidate $name (++$order) $settings[$name].Description $null @() $settings[$name].Description }
        }

        'Role' {
            Initialize-MtRoleDefinition
            $order = 0
            foreach ($name in (@($script:MtRoles.Keys) + @($script:MtRoleAliases.Keys) | Sort-Object -Unique)) { & $candidate $name (++$order) $name }
        }
    }
}
