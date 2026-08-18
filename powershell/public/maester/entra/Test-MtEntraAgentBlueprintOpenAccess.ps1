function Test-MtEntraAgentBlueprintOpenAccess {
    <#
    .SYNOPSIS
    Finds Agent Identity Blueprint Principals that expose app roles without requiring assignment.
    .DESCRIPTION
    Checks whether any Agent Identity Blueprint Principal declares application roles while
    appRoleAssignmentRequired is false. When assignment isn't required, any principal in the tenant
    can be issued a token for those roles without being explicitly assigned first, widening who can
    call into resources the Blueprint exposes.
    .EXAMPLE
    Test-MtEntraAgentBlueprintOpenAccess
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentBlueprintOpenAccess
    .LINK
    https://learn.microsoft.com/graph/api/agentidentityblueprintprincipal-list?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identity Blueprint Principals.'
        $BlueprintPrincipals = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' `
                -Select @('id', 'displayName', 'appId', 'appRoleAssignmentRequired', 'appRoles')
        )

        Write-Verbose "Found $($BlueprintPrincipals.Count) Agent Identity Blueprint Principals."

        if ($BlueprintPrincipals.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Identity Blueprint Principals were found in the tenant.'
            )
            return $true
        }

        $OpenAccessFindings = [System.Collections.Generic.List[pscustomobject]]::new()

        foreach ($Principal in $BlueprintPrincipals) {
            # @($null) is a one-element array, not an empty one, so a null appRoles
            # property must be filtered out explicitly rather than just wrapped in @().
            $AppRoleCount = @($Principal.appRoles | Where-Object { $null -ne $_ }).Count
            if ($Principal.appRoleAssignmentRequired -eq $false -and $AppRoleCount -gt 0) {
                $OpenAccessFindings.Add([pscustomobject]@{
                    ObjectId    = [string]$Principal.id
                    DisplayName = [string]$Principal.displayName
                    AppId       = [string]$Principal.appId
                    RoleCount   = $AppRoleCount
                })
            }
        }

        if ($OpenAccessFindings.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. Every Agent Identity Blueprint Principal that exposes application roles requires assignment before a token can be issued for them.'
            )
            return $true
        }

        $Result = "Found $($OpenAccessFindings.Count) Agent Identity Blueprint Principal(s) exposing application roles without requiring assignment."
        $Result += "`n`n| Object ID | Display name | App ID | Exposed app role(s) |"
        $Result += "`n| --- | --- | --- | --- |"
        foreach ($Item in $OpenAccessFindings) {
            $Name = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
            $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
            $Name = $Name -replace "`r?`n", ' '
            $Result += "`n| ``$($Item.ObjectId)`` | $Name | ``$($Item.AppId)`` | $($Item.RoleCount) |"
        }

        Add-MtTestResultDetail -Result $Result -Severity 'Medium'
        return $false
    } catch {
        $ErrorRecord = $_
    }

    if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
    } else {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
    }
    return $null
}
