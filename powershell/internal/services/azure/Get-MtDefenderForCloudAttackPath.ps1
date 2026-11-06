function Get-MtDefenderForCloudAttackPath {
    <#
    .SYNOPSIS
    Returns the Microsoft Defender for Cloud attack paths grouped by path, together with whether
    Defender CSPM is enabled on any readable subscription.

    .DESCRIPTION
    Attack paths are computed by Defender CSPM, so an empty result has two very different meanings:
    the plan is off and nothing was ever computed, or the plan is on and the estate genuinely has no
    path. The returned object separates them. CspmEnabled comes from the Defender for Cloud pricing of
    CloudPosture, which Azure Resource Graph exposes as microsoft.security/pricings, so the caller can
    report "not licensed" instead of a pass.

    On the fields, measured against a live Defender CSPM subscription rather than assumed:

    - properties.attackPathType is a GUID and properties.displayName is a sentence. The engine
      requires an instance ID matching ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$, so the GUID is the ID of
      the path type and the sentence is the title. Grouping by the GUID is also what "one result per
      attack path type" means: the sentence can repeat across occurrences of the same type.
    - properties.entryPoint carries entityInternalId, entityType and dataSource, and no entity name,
      so the entry point is reported by its resource type.
    - properties.target does carry entityName as well as entityType, so the target is named.
    - properties.riskFactors and properties.mITRETacticsAndTechniques.tactics are arrays. Azure
      Resource Graph does not support mv-apply, so they are carried as their JSON text and parsed
      here.

    .EXAMPLE
    Get-MtDefenderForCloudAttackPath

    Returns whether Defender CSPM is on and the attack paths grouped by path.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    # Defender CSPM is the plan that computes attack paths. Its pricing row is the only way to tell an
    # estate with no path from a subscription that never had the plan on.
    $pricingQuery = @'
securityresources
| where type == "microsoft.security/pricings"
| where name == "CloudPosture"
| summarize StandardCount = countif(tostring(properties.pricingTier) == "Standard")
'@

    Write-Verbose 'Checking whether Defender CSPM is enabled...'
    $pricing = @(Invoke-MtAzureResourceGraphRequest -Query $pricingQuery) | Select-Object -First 1
    $cspmEnabled = $null -ne $pricing -and [int]($pricing.StandardCount) -gt 0

    $pathQuery = @'
securityresources
| where type == "microsoft.security/attackpaths"
| extend nombre = tostring(properties.displayName),
         riesgo = tostring(properties.riskLevel),
         parcial = tostring(properties.isPartialAttackPath),
         factores = tostring(properties.riskFactors),
         tacticas = tostring(properties.mITRETacticsAndTechniques.tactics),
         tipoEntrada = tostring(properties.entryPoint.entityType),
         nombreDestino = tostring(properties.target.entityName),
         tipoDestino = tostring(properties.target.entityType)
| summarize PathCount = count(),
            DisplayName = any(nombre),
            RiskLevel = any(riesgo),
            Partial = any(parcial),
            RiskFactorsJson = any(factores),
            TacticsJson = any(tacticas),
            EntryPointTypeList = make_set(tipoEntrada, 10),
            TargetList = make_set(nombreDestino, 10),
            TargetTypeList = make_set(tipoDestino, 10)
    by AttackPathType = tostring(properties.attackPathType)
| sort by PathCount desc, AttackPathType asc
'@

    Write-Verbose 'Querying Defender for Cloud attack paths...'
    $rows = @(Invoke-MtAzureResourceGraphRequest -Query $pathQuery)

    # The arrays arrive as JSON text because Azure Resource Graph has no mv-apply.
    function ConvertFrom-MtJsonArray {
        param([string] $Text)
        if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
        try { return @($Text | ConvertFrom-Json) } catch { return @() }
    }

    $paths = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($row in $rows) {
        if (-not $row -or [string]::IsNullOrWhiteSpace([string]$row.AttackPathType)) { continue }
        $paths.Add([pscustomobject]@{
                AttackPathType     = [string]$row.AttackPathType
                DisplayName        = [string]$row.DisplayName
                RiskLevel          = [string]$row.RiskLevel
                PathCount          = [int]($row.PathCount)
                RiskFactorList     = ConvertFrom-MtJsonArray -Text ([string]$row.RiskFactorsJson)
                TacticList         = ConvertFrom-MtJsonArray -Text ([string]$row.TacticsJson)
                EntryPointTypeList = @($row.EntryPointTypeList | Where-Object { $_ })
                TargetList         = @($row.TargetList | Where-Object { $_ })
                TargetTypeList     = @($row.TargetTypeList | Where-Object { $_ })
            })
    }

    [pscustomobject]@{
        CspmEnabled = $cspmEnabled
        PathList    = $paths
    }
}
