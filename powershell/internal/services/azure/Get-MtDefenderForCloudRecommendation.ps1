function Get-MtDefenderForCloudRecommendation {
    <#
    .SYNOPSIS
    Returns one row per Microsoft Defender for Cloud recommendation across the subscriptions the
    signed-in account can read, with how many resources are healthy, unhealthy, not applicable and
    exempt.

    .DESCRIPTION
    Runs a single Azure Resource Graph query over securityresources, aggregated server side so the
    result is one row per recommendation rather than one row per resource and recommendation. A large
    estate produces thousands of assessment rows and only hundreds of recommendations, which is the
    difference the caller needs to stay readable.

    Each row carries the recommendation's assessment key, display name, severity from its metadata, the
    risk level Defender CSPM adds when it is enabled, the portal link, the resource counts, a capped
    sample of the unhealthy resource names, and the exemption cause when every resource is exempt.

    An empty result means Defender for Cloud produced no assessment for these subscriptions. The caller
    must skip in that case: no unhealthy resource over no assessment is not a pass.

    Errors are deliberately not caught here, so a failed query surfaces instead of being read as a
    clean estate.

    .EXAMPLE
    Get-MtDefenderForCloudRecommendation

    Returns the Defender for Cloud recommendations with their resource counts.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param()

    # Aggregated server side: one row per assessment key. make_set is capped because a recommendation
    # can be unhealthy on thousands of resources and the result is a summary, not an inventory.
    $query = @'
securityresources
| where type == "microsoft.security/assessments"
| extend estado = tostring(properties.status.code),
         causa = tostring(properties.status.cause),
         nombre = tostring(properties.displayName),
         severidad = tostring(properties.metadata.severity),
         riesgo = tostring(properties.risk.level),
         portal = tostring(properties.links.azurePortal)
| summarize TotalCount = count(),
            UnhealthyCount = countif(estado == "Unhealthy"),
            HealthyCount = countif(estado == "Healthy"),
            NotApplicableCount = countif(estado == "NotApplicable"),
            ExemptCount = countif(causa == "Exempt"),
            UnhealthyResourceList = make_set_if(tostring(split(id, "/")[8]), estado == "Unhealthy", 10),
            DisplayName = any(nombre),
            Severity = any(severidad),
            RiskLevel = any(riesgo),
            PortalUri = any(portal)
    by AssessmentKey = name
| sort by UnhealthyCount desc, AssessmentKey asc
'@

    Write-Verbose 'Querying Defender for Cloud assessments through Azure Resource Graph...'
    $rows = @(Invoke-MtAzureResourceGraphRequest -Query $query)

    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($row in $rows) {
        if (-not $row -or [string]::IsNullOrWhiteSpace([string]$row.AssessmentKey)) { continue }
        $result.Add([pscustomobject]@{
                AssessmentKey         = [string]$row.AssessmentKey
                DisplayName           = [string]$row.DisplayName
                Severity              = [string]$row.Severity
                RiskLevel             = [string]$row.RiskLevel
                PortalUri             = [string]$row.PortalUri
                TotalCount            = [int]($row.TotalCount)
                UnhealthyCount        = [int]($row.UnhealthyCount)
                HealthyCount          = [int]($row.HealthyCount)
                NotApplicableCount    = [int]($row.NotApplicableCount)
                ExemptCount           = [int]($row.ExemptCount)
                UnhealthyResourceList = @($row.UnhealthyResourceList)
            })
    }

    # -NoEnumerate keeps an empty list from collapsing to $null.
    Write-Output $result -NoEnumerate
}
