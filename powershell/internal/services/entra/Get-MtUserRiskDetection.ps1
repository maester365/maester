function Get-MtUserRiskDetection {
    <#
    .SYNOPSIS
    Returns the Entra ID Protection user risk detections that are still open.

    .DESCRIPTION
    Reads identityProtection/riskDetections (Microsoft Graph v1.0) and returns the detections whose risk
    state is atRisk or confirmedCompromised: the detections nobody has remediated, dismissed or confirmed
    safe. Each state is read with its own single-property filter, because Graph rejects some compound
    filters on the Identity Protection endpoints, and each read goes through the Graph cache so the
    checks that call this in one run share the same two requests.

    Graph keeps risk detections for 90 days, so older detections are not returned. The API needs
    Microsoft Entra ID P1 or P2 and the IdentityRiskEvent.Read.All permission.

    .EXAMPLE
    Get-MtUserRiskDetection | Group-Object riskEventType

    Counts the open user risk detections by detection type.

    .LINK
    https://learn.microsoft.com/graph/api/riskdetection-list?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $select = @(
        'id', 'riskEventType', 'riskLevel', 'riskState', 'riskDetail', 'activity', 'detectionTimingType',
        'ipAddress', 'location', 'activityDateTime', 'detectedDateTime', 'lastUpdatedDateTime',
        'userId', 'userDisplayName', 'userPrincipalName'
    )

    foreach ($state in @('atRisk', 'confirmedCompromised')) {
        Invoke-MtGraphRequest -ApiVersion 'v1.0' `
            -RelativeUri 'identityProtection/riskDetections' `
            -Filter "riskState eq '$state'" `
            -Select $select
    }
}
