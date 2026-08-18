function Test-MtEntraAgentOwner {
    <#
    .SYNOPSIS
    Finds Agent Identities, Blueprint Principals, and Blueprints without valid, enabled owners.
    .DESCRIPTION
    Checks that every Agent Identity, Agent Identity Blueprint Principal, and Agent Identity Blueprint
    has at least one active, enabled owner. Ownerless objects or objects whose owners are all disabled
    leave AI agents unmanaged and increase the risk of unauthorized access or orphaned privileges.
    .EXAMPLE
    Test-MtEntraAgentOwner
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentOwner
    .LINK
    https://learn.microsoft.com/graph/api/serviceprincipal-list-owners?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identities, Blueprint Principals, and Blueprints for owner checks.'
        $AgentIdentities = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'displayName')
        )
        $BlueprintPrincipals = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' `
                -Select @('id', 'displayName')
        )
        $Blueprints = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                -Select @('id', 'displayName', 'appId')
        )

        Write-Verbose (
            "Evaluating owners for $($AgentIdentities.Count) Agent Identities, " +
            "$($BlueprintPrincipals.Count) Blueprint Principals, and $($Blueprints.Count) Blueprints."
        )

        $OwnerlessObjects = [System.Collections.Generic.List[pscustomobject]]::new()

        # Check Agent Identities
        foreach ($AgentIdentity in $AgentIdentities) {
            $IdentityId = [string]$AgentIdentity.id
            if ([string]::IsNullOrWhiteSpace($IdentityId)) { continue }

            $Owners = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                    -RelativeUri "servicePrincipals/$IdentityId/owners" `
                    -Select @('id', 'displayName', 'accountEnabled', 'userPrincipalName')
            )

            $ActiveOwners = @($Owners | Where-Object { $null -eq $_.accountEnabled -or $_.accountEnabled -eq $true })
            if ($Owners.Count -eq 0) {
                $OwnerlessObjects.Add([pscustomobject]@{
                    ObjectId    = $IdentityId
                    DisplayName = [string]$AgentIdentity.displayName
                    ObjectType  = 'Agent Identity'
                    Reason      = 'No owners are assigned.'
                })
            } elseif ($ActiveOwners.Count -eq 0) {
                $OwnerlessObjects.Add([pscustomobject]@{
                    ObjectId    = $IdentityId
                    DisplayName = [string]$AgentIdentity.displayName
                    ObjectType  = 'Agent Identity'
                    Reason      = 'All assigned owners are disabled accounts.'
                })
            }
        }

        # Check Blueprint Principals
        foreach ($BlueprintPrincipal in $BlueprintPrincipals) {
            $PrincipalId = [string]$BlueprintPrincipal.id
            if ([string]::IsNullOrWhiteSpace($PrincipalId)) { continue }

            $Owners = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                    -RelativeUri "servicePrincipals/$PrincipalId/owners" `
                    -Select @('id', 'displayName', 'accountEnabled', 'userPrincipalName')
            )

            $ActiveOwners = @($Owners | Where-Object { $null -eq $_.accountEnabled -or $_.accountEnabled -eq $true })
            if ($Owners.Count -eq 0) {
                $OwnerlessObjects.Add([pscustomobject]@{
                    ObjectId    = $PrincipalId
                    DisplayName = [string]$BlueprintPrincipal.displayName
                    ObjectType  = 'Blueprint Principal'
                    Reason      = 'No owners are assigned.'
                })
            } elseif ($ActiveOwners.Count -eq 0) {
                $OwnerlessObjects.Add([pscustomobject]@{
                    ObjectId    = $PrincipalId
                    DisplayName = [string]$BlueprintPrincipal.displayName
                    ObjectType  = 'Blueprint Principal'
                    Reason      = 'All assigned owners are disabled accounts.'
                })
            }
        }

        # Check Blueprints
        foreach ($Blueprint in $Blueprints) {
            $BlueprintId = [string]$Blueprint.id
            if ([string]::IsNullOrWhiteSpace($BlueprintId)) { continue }

            $Owners = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                    -RelativeUri "applications/$BlueprintId/owners" `
                    -Select @('id', 'displayName', 'accountEnabled', 'userPrincipalName')
            )

            $ActiveOwners = @($Owners | Where-Object { $null -eq $_.accountEnabled -or $_.accountEnabled -eq $true })
            if ($Owners.Count -eq 0) {
                $OwnerlessObjects.Add([pscustomobject]@{
                    ObjectId    = $BlueprintId
                    DisplayName = [string]$Blueprint.displayName
                    ObjectType  = 'Agent Blueprint'
                    Reason      = 'No owners are assigned.'
                })
            } elseif ($ActiveOwners.Count -eq 0) {
                $OwnerlessObjects.Add([pscustomobject]@{
                    ObjectId    = $BlueprintId
                    DisplayName = [string]$Blueprint.displayName
                    ObjectType  = 'Agent Blueprint'
                    Reason      = 'All assigned owners are disabled accounts.'
                })
            }
        }

        if ($OwnerlessObjects.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. All Agent Identities, Blueprint Principals, and Blueprints have active, enabled owners.'
            )
            return $true
        }

        $Result = "Found $($OwnerlessObjects.Count) Agent ID object(s) without valid, active owners."
        $Result += "`n`n| Object ID | Display name | Object type | Reason |"
        $Result += "`n| --- | --- | --- | --- |"
        foreach ($Item in $OwnerlessObjects) {
            $DisplayName = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
            $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
            $DisplayName = $DisplayName -replace "`r?`n", ' '
            $Reason = [System.Net.WebUtility]::HtmlEncode([string]$Item.Reason) -replace '\|', '&#124;'
            $Result += "`n| ``$($Item.ObjectId)`` | $DisplayName | $($Item.ObjectType) | $Reason |"
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
