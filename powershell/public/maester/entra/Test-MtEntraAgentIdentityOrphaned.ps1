function Test-MtEntraAgentIdentityOrphaned {
    <#
    .SYNOPSIS
    Finds Agent Identities without an existing Agent Identity Blueprint Principal.
    .DESCRIPTION
    Checks that each Agent Identity still has a corresponding Agent Identity Blueprint Principal.
    Without that parent, the identity may no longer be able to authenticate or be managed through
    its blueprint.
    .EXAMPLE
    Test-MtEntraAgentIdentityOrphaned
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentIdentityOrphaned
    .LINK
    https://learn.microsoft.com/graph/api/agentidentity-list?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identities and Blueprint Principals.'
        $AgentIdentities = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'displayName', 'agentIdentityBlueprintId')
        )
        $BlueprintPrincipals = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' `
                -Select @('id', 'displayName', 'appId')
        )
        Write-Verbose (
            "Found $($AgentIdentities.Count) Agent Identities and " +
            "$($BlueprintPrincipals.Count) Blueprint Principals."
        )

        $BlueprintsByAppId = @{}
        foreach ($BlueprintPrincipal in $BlueprintPrincipals) {
            $AppId = [string]$BlueprintPrincipal.appId
            if (![string]::IsNullOrWhiteSpace($AppId)) {
                $BlueprintsByAppId[$AppId] = $BlueprintPrincipal
            }
        }

        $OrphanedIdentities = @(
            foreach ($AgentIdentity in $AgentIdentities) {
                $BlueprintAppId = [string]$AgentIdentity.agentIdentityBlueprintId
                if ([string]::IsNullOrWhiteSpace($BlueprintAppId)) {
                    [pscustomobject]@{
                        AgentIdentityId = [string]$AgentIdentity.id
                        DisplayName      = [string]$AgentIdentity.displayName
                        BlueprintAppId   = ''
                        Reason           = 'No Blueprint App ID is associated with this identity.'
                    }
                    continue
                }

                if (!$BlueprintsByAppId.ContainsKey($BlueprintAppId)) {
                    [pscustomobject]@{
                        AgentIdentityId = [string]$AgentIdentity.id
                        DisplayName      = [string]$AgentIdentity.displayName
                        BlueprintAppId   = $BlueprintAppId
                        Reason           = 'The Blueprint App ID does not match an existing ' +
                            'Agent Identity Blueprint Principal.'
                    }
                }
            }
        )

        if ($OrphanedIdentities.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No orphaned Agent Identities were found. Every Agent Identity is ' +
                'linked to an existing Agent Identity Blueprint Principal.'
            )
            return $true
        }

        $Result = "Found $($OrphanedIdentities.Count) Agent Identity object(s) without a " +
            'matching Agent Identity Blueprint Principal.'
        $Result += ' Review the identity and its access before disabling, deleting, or restoring ' +
            'anything.'
        $Result += "`n`n| Agent Identity object ID | Display name | Blueprint App ID | Reason |"
        $Result += "`n| --- | --- | --- | --- |"
        foreach ($OrphanedIdentity in $OrphanedIdentities) {
            $DisplayName = [string]$OrphanedIdentity.DisplayName
            if ([string]::IsNullOrWhiteSpace($DisplayName)) {
                $DisplayName = '(unnamed)'
            }
            $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
            $DisplayName = $DisplayName -replace "`r?`n", ' '
            $Reason = [string]$OrphanedIdentity.Reason -replace '\|', '\|'
            $Result += "`n| $($OrphanedIdentity.AgentIdentityId) | $DisplayName | " +
                "$($OrphanedIdentity.BlueprintAppId) | $Reason |"
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
