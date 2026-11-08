function Get-MtServicePrincipalRiskDetection {
    <#
    .SYNOPSIS
    Returns the Entra ID Protection workload identity risk detections that are still open.

    .DESCRIPTION
    Reads identityProtection/servicePrincipalRiskDetections (Microsoft Graph v1.0) and returns the
    detections whose risk state is atRisk or confirmedCompromised: the detections nobody has remediated
    or dismissed. Each state is read with its own single-property filter, because Graph rejects some
    compound filters on the Identity Protection endpoints, and each read goes through the Graph cache so
    the checks that call this in one run share the same two requests.

    Graph keeps risk detections for 90 days, so older detections are not returned. The API needs a
    Microsoft Entra Workload ID Premium licence and the IdentityRiskEvent.Read.All permission.

    .EXAMPLE
    Get-MtServicePrincipalRiskDetection | Group-Object riskEventType

    Counts the open workload identity risk detections by detection type.

    .LINK
    https://learn.microsoft.com/graph/api/identityprotectionroot-list-serviceprincipalriskdetections?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $select = @(
        'id', 'riskEventType', 'riskLevel', 'riskState', 'riskDetail', 'activity', 'detectionTimingType',
        'ipAddress', 'location', 'activityDateTime', 'detectedDateTime', 'lastUpdatedDateTime',
        'servicePrincipalId', 'servicePrincipalDisplayName', 'appId', 'keyIds'
    )

    foreach ($state in @('atRisk', 'confirmedCompromised')) {
        Invoke-MtGraphRequest -ApiVersion 'v1.0' `
            -RelativeUri 'identityProtection/servicePrincipalRiskDetections' `
            -Filter "riskState eq '$state'" `
            -Select $select
    }
}
