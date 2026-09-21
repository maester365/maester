function Test-MtEntraAgentBlueprintOrphaned {
    <#
    .SYNOPSIS
    Finds Agent Identity Blueprint Principals whose Blueprint is missing.
    .DESCRIPTION
    Checks whether each Agent Identity Blueprint Principal still has its Blueprint. If the
    Blueprint is missing, the Principal and its Agent Identities lose that managed parent.
    .EXAMPLE
    Test-MtEntraAgentBlueprintOrphaned
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentBlueprintOrphaned
    .LINK
    https://learn.microsoft.com/graph/api/agentidentityblueprint-list?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }
    try {
        Write-Verbose 'Reading Agent Identities, Blueprint Principals, and Blueprints.'
        $AgentIdentities = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'displayName', 'agentIdentityBlueprintId'))
        $BlueprintPrincipals = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' `
                -Select @('id', 'displayName', 'appId'))
        $Blueprints = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                -Select @('id', 'displayName', 'appId'))
        $BlueprintsByAppId = @{}
        foreach ($Blueprint in $Blueprints) {
            $AppId = [string]$Blueprint.appId
            if ([string]::IsNullOrWhiteSpace($AppId)) {
                throw 'Graph returned an Agent Identity Blueprint without an app ID.'
            }
            $BlueprintsByAppId[$AppId] = $Blueprint
        }
        $IdentityIdsByAppId = @{}
        foreach ($AgentIdentity in $AgentIdentities) {
            $AppId = [string]$AgentIdentity.agentIdentityBlueprintId
            if (![string]::IsNullOrWhiteSpace($AppId)) {
                if (!$IdentityIdsByAppId.ContainsKey($AppId)) {
                    $IdentityIdsByAppId[$AppId] = [System.Collections.Generic.List[string]]::new()
                }
                $IdentityIdsByAppId[$AppId].Add([string]$AgentIdentity.id)
            }
        }
        $OrphanedPrincipals = @(
            foreach ($BlueprintPrincipal in $BlueprintPrincipals) {
                $AppId = [string]$BlueprintPrincipal.appId
                if ([string]::IsNullOrWhiteSpace($AppId)) {
                    throw 'Graph returned an Agent Identity Blueprint Principal without an app ID.'
                }
                if (!$BlueprintsByAppId.ContainsKey($AppId)) {
                    $LinkedIdentityIds = if ($IdentityIdsByAppId.ContainsKey($AppId)) {
                        @($IdentityIdsByAppId[$AppId])
                    } else {
                        @()
                    }
                    [pscustomobject]@{
                        PrincipalId      = [string]$BlueprintPrincipal.id
                        DisplayName      = [string]$BlueprintPrincipal.displayName
                        BlueprintAppId   = $AppId
                        AgentIdentityIds = $LinkedIdentityIds
                    }
                }
            }
        )
        if ($OrphanedPrincipals.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. Every Agent Identity Blueprint Principal has an existing Blueprint.'
            )
            return $true
        }
        $Result = "Found $($OrphanedPrincipals.Count) Blueprint Principal object(s) whose " +
            'Agent Identity Blueprint is missing.'
        $Result += "`n`n| Blueprint Principal object ID | Display name | Blueprint App ID | " +
            "Linked Agent Identity object IDs |`n| --- | --- | --- | --- |"
        foreach ($Principal in $OrphanedPrincipals) {
            $Name = [System.Net.WebUtility]::HtmlEncode($Principal.DisplayName)
            $Name = $Name -replace '\|', '&#124;'
            $Name = $Name -replace "`r?`n", ' '
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
            $IdentityIds = if ($Principal.AgentIdentityIds.Count -gt 0) {
                $Principal.AgentIdentityIds -join ', '
            } else { '(none found)' }
            $Result += "`n| $($Principal.PrincipalId) | $Name | " +
                "$($Principal.BlueprintAppId) | $IdentityIds |"
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
