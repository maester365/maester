function Get-MtTaxonomy {
    <#
    .SYNOPSIS
    Returns the taxonomy registry (assets/MaesterTaxonomy.psd1). Cached for the session.

    .DESCRIPTION
    The registry lists the products (with their features and aliases), the areas and the resource types that
    the classification attributes of [MaesterTest] use (test attribute design, section 2.2). The order of
    Products is the order of the console lanes and of product lists in reports.

    The returned table also has Lookup, built once, with case-insensitive tables: Product (key or alias to
    the product), Feature (product key to a table of its features by key), Area and ResourceType (key to
    the entry).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if (-not $script:__MtTaxonomy) {
        $taxonomy = Import-PowerShellDataFile -Path (Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterTaxonomy.psd1')
        $ignoreCase = [System.StringComparer]::OrdinalIgnoreCase
        $lookup = @{
            Product      = [System.Collections.Generic.Dictionary[string, object]]::new($ignoreCase)
            Feature      = [System.Collections.Generic.Dictionary[string, object]]::new($ignoreCase)
            Area         = [System.Collections.Generic.Dictionary[string, object]]::new($ignoreCase)
            ResourceType = [System.Collections.Generic.Dictionary[string, object]]::new($ignoreCase)
        }
        foreach ($product in $taxonomy.Products) {
            # A key always wins over an alias of another product.
            $lookup.Product[$product.Key] = $product
            $features = [System.Collections.Generic.Dictionary[string, object]]::new($ignoreCase)
            foreach ($feature in @($product.Features)) { $features[$feature.Key] = $feature }
            $lookup.Feature[$product.Key] = $features
        }
        foreach ($product in $taxonomy.Products) {
            foreach ($alias in @($product.Aliases)) { if (-not $lookup.Product.ContainsKey($alias)) { $lookup.Product[$alias] = $product } }
        }
        foreach ($area in $taxonomy.Areas) { $lookup.Area[$area.Key] = $area }
        foreach ($type in $taxonomy.ResourceTypes) { $lookup.ResourceType[$type.Key] = $type }
        $taxonomy.Lookup = $lookup
        $script:__MtTaxonomy = $taxonomy
    }
    $script:__MtTaxonomy
}

function Resolve-MtProductKey {
    <#
    .SYNOPSIS
    Returns the key of a product named by its key or an alias, case-insensitively, or $null.

    .EXAMPLE
    Resolve-MtProductKey -Name 'Entra ID'

    Returns entra.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Name,
        [Parameter()] [hashtable] $Taxonomy = (Get-MtTaxonomy)
    )
    $product = $null
    if ($Name -and $Taxonomy.Lookup.Product.TryGetValue($Name, [ref] $product)) { return [string]$product.Key }
    $null
}

function Get-MtProductName {
    <#
    .SYNOPSIS
    Returns the display name of a product key or alias, or the value as written when the registry does not know it.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowNull()] [AllowEmptyString()] [string] $Product,
        [Parameter()] [hashtable] $Taxonomy = (Get-MtTaxonomy)
    )
    $entry = $null
    if ($Product -and $Taxonomy.Lookup.Product.TryGetValue($Product, [ref] $entry)) { return [string]$entry.Name }
    $Product
}

function Get-MtAttackData {
    <#
    .SYNOPSIS
    Returns the pinned MITRE ATT&CK release (assets/MaesterAttackTechniques.json). Cached for the session.

    .DESCRIPTION
    The file is a trimmed copy of one ATT&CK Enterprise release: tactic and technique IDs and names, and the
    technique IDs that release retired. Returns Version, TechniqueList and TacticList (the entries in the
    order of the file), Techniques and Tactics (ID to the entry, case-insensitive) and Retired (a set of
    IDs). The Mitre attribute is validated against it by the build and the unit tests, never at run time.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if (-not $script:__MtAttackData) {
        $taxonomy = Get-MtTaxonomy
        $file = Join-Path $ExecutionContext.SessionState.Module.ModuleBase "assets/$($taxonomy.Attack.File)"
        $data = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        $ignoreCase = [System.StringComparer]::OrdinalIgnoreCase
        $techniques = [System.Collections.Generic.Dictionary[string, object]]::new($ignoreCase)
        foreach ($technique in $data.Techniques) { $techniques[[string]$technique.Id] = $technique }
        $tactics = [System.Collections.Generic.Dictionary[string, object]]::new($ignoreCase)
        foreach ($tactic in $data.Tactics) { $tactics[[string]$tactic.Id] = $tactic }
        $retired = [System.Collections.Generic.HashSet[string]]::new([string[]]@($data.Retired), $ignoreCase)
        $script:__MtAttackData = [pscustomobject]@{
            Version       = [string]$data.Version
            TechniqueList = @($data.Techniques)
            TacticList    = @($data.Tactics)
            Techniques    = $techniques
            Tactics       = $tactics
            Retired       = $retired
        }
    }
    $script:__MtAttackData
}

function Get-MtAttackTechniqueProblem {
    <#
    .SYNOPSIS
    Returns one message for each Mitre value that the pinned ATT&CK release retired or does not know.

    .DESCRIPTION
    Used by the catalog build, which fails on any message, and by the unit tests. None is not a technique
    and is never a problem.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [string[]] $Mitre
    )

    $attack = Get-MtAttackData
    foreach ($id in @($Mitre | Where-Object { $_ -and $_ -ne 'None' })) {
        if ($attack.Techniques.ContainsKey($id)) { continue }
        if ($attack.Retired.Contains($id)) { "ATT&CK technique $id was retired in ATT&CK $($attack.Version)." }
        else { "ATT&CK technique $id is not in ATT&CK $($attack.Version)." }
    }
}

function Get-MtResultTaxonomy {
    <#
    .SYNOPSIS
    Builds the Taxonomy object of a result or of the test catalog (test attribute design, section 3).

    .DESCRIPTION
    Lets a consumer render names without the module: the products, features, areas and resource types of the
    registry and the ATT&CK techniques with their tactics. For a result it lists only what the given rows
    use; -All lists the whole registry and the whole pinned ATT&CK release, for the catalog. A value that is
    not in the registry (a custom test may use any value) has no entry.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Result rows or tests with Product, RelatedProduct, Feature, Area, ResourceType and Mitre.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $InputObject = @(),

        # The whole registry and ATT&CK release instead of what the rows use.
        [Parameter()] [switch] $All
    )

    $taxonomy = Get-MtTaxonomy
    $attack = Get-MtAttackData
    $ignoreCase = [System.StringComparer]::OrdinalIgnoreCase
    $usedProducts = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
    $usedFeatures = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
    $usedAreas = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
    $usedTypes = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
    $usedTechniques = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
    if (-not $All) {
        foreach ($row in $InputObject) {
            if ($null -eq $row) { continue }
            $value = { param($name) if ($row.PSObject.Properties[$name]) { $row.$name } }
            $product = [string](& $value 'Product')
            foreach ($p in @($product) + @(& $value 'RelatedProduct')) { if ($p) { $null = $usedProducts.Add([string]$p) } }
            $feature = [string](& $value 'Feature')
            if ($product -and $feature) { $null = $usedFeatures.Add("$product|$feature") }
            foreach ($a in @(& $value 'Area')) { if ($a) { $null = $usedAreas.Add([string]$a) } }
            foreach ($t in @(& $value 'ResourceType')) { if ($t) { $null = $usedTypes.Add([string]$t) } }
            foreach ($m in @(& $value 'Mitre')) { if ($m) { $null = $usedTechniques.Add([string]$m) } }
        }
    }

    $products = @(foreach ($p in $taxonomy.Products) {
            if ($All -or $usedProducts.Contains($p.Key)) { [pscustomobject][ordered]@{ Key = $p.Key; Name = $p.Name } }
        })
    $features = @(foreach ($p in $taxonomy.Products) {
            foreach ($f in @($p.Features)) {
                if ($All -or $usedFeatures.Contains("$($p.Key)|$($f.Key)")) { [pscustomobject][ordered]@{ Product = $p.Key; Key = $f.Key; Name = $f.Name } }
            }
        })
    $areas = @(foreach ($a in $taxonomy.Areas) {
            if ($All -or $usedAreas.Contains($a.Key)) { [pscustomobject][ordered]@{ Key = $a.Key; Name = $a.Name } }
        })
    $types = @(foreach ($t in $taxonomy.ResourceTypes) {
            if ($All -or $usedTypes.Contains($t.Key)) { [pscustomobject][ordered]@{ Key = $t.Key } }
        })
    # Techniques and tactics in the order of the pinned release.
    $techniques = @(foreach ($t in $attack.TechniqueList) {
            if ($All -or $usedTechniques.Contains([string]$t.Id)) { [pscustomobject][ordered]@{ Id = [string]$t.Id; Name = [string]$t.Name; Tactics = @($t.Tactics) } }
        })
    $usedTactics = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
    foreach ($t in $techniques) { foreach ($tactic in $t.Tactics) { $null = $usedTactics.Add([string]$tactic) } }
    $tactics = @(foreach ($t in $attack.TacticList) {
            if ($All -or $usedTactics.Contains([string]$t.Id)) { [pscustomobject][ordered]@{ Id = [string]$t.Id; Name = [string]$t.Name } }
        })

    [pscustomobject][ordered]@{
        Products      = $products
        Features      = $features
        Areas         = $areas
        ResourceTypes = $types
        Attack        = [pscustomobject][ordered]@{
            Version    = $attack.Version
            Techniques = $techniques
            Tactics    = $tactics
        }
    }
}
