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
| extend displayName = tostring(properties.displayName),
         risk = tostring(properties.riskLevel),
         parcial = tostring(properties.isPartialAttackPath),
         riskFactors = tostring(properties.riskFactors),
         tactics = tostring(properties.mITRETacticsAndTechniques.tactics),
         tipoEntrada = tostring(properties.entryPoint.entityType),
         targetName = tostring(properties.target.entityName),
         tipoDestino = tostring(properties.target.entityType)
// A risk level is per occurrence, so a group holds several. any() picked one at random, and it
// picked independently for the risk factors and the tactics, so the three could describe different
// occurrences of the same attack path type. arg_max takes all three from the one that ranks worst.
| extend riskRank = case(risk =~ "Critical", 4, risk =~ "High", 3, risk =~ "Medium", 2, risk =~ "Low", 1, 0)
| summarize PathCount = count(),
            DisplayName = any(displayName),
            Partial = any(parcial),
            EntryPointTypeList = make_set(tipoEntrada, 10),
            TargetList = make_set(targetName, 10),
            // make_set is capped, so the consumer needs to know when it is showing a subset.
            TargetTotal = dcount(targetName),
            TargetTypeList = make_set(tipoDestino, 10),
            (RiskRank, RiskLevel, RiskFactorsJson, TacticsJson) = arg_max(riskRank, risk, riskFactors, tactics)
    by AttackPathType = tostring(properties.attackPathType)
| project-away RiskRank
| sort by PathCount desc, AttackPathType asc
'@

    Write-Verbose 'Querying Defender for Cloud attack paths...'
    $rows = @(Invoke-MtAzureResourceGraphRequest -Query $pathQuery)

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
                # make_set is capped at 10; this is how many distinct targets there really are.
                TargetTotal        = [int]($row.TargetTotal)
                TargetTypeList     = @($row.TargetTypeList | Where-Object { $_ })
            })
    }

    [pscustomobject]@{
        CspmEnabled = $cspmEnabled
        PathList    = $paths
    }
}
