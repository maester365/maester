function Test-MtEntraAgentForeignPrivileged {
    <#
    .SYNOPSIS
    Finds foreign or multi-tenant Agent Blueprint Principals and Agent Identities with privileged access.
    .DESCRIPTION
    Checks whether Blueprint Principals owned by an external tenant (multi-tenant applications)
    or their child Agent Identities have been granted an Entra directory role that Maester's
    built-in role catalogue classifies as privileged through Get-MtRoleInfo. Application
    permissions held by a foreign Blueprint Principal are reported as an observation for review,
    not as a failure.
    .EXAMPLE
    Test-MtEntraAgentForeignPrivileged
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentForeignPrivileged
    .LINK
    https://learn.microsoft.com/graph/api/serviceprincipal-list-approleassignments?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading tenant organization context.'
        $Org = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'organization' `
                -Select @('id', 'displayName')
        )
        $CurrentTenantId = if ($Org.Count -gt 0) { [string]$Org[0].id } else { '' }

        if ([string]::IsNullOrWhiteSpace($CurrentTenantId)) {
            Write-Verbose 'Unable to determine local tenant ID; falling back to context token.'
            $CurrentTenantId = [string](Get-MgContext).TenantId
        }
        if ([string]::IsNullOrWhiteSpace($CurrentTenantId)) {
            throw 'Unable to determine the current tenant ID from Graph or the connection context.'
        }

        Write-Verbose 'Reading Agent Identity Blueprint Principals.'
        $BlueprintPrincipals = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' `
                -Select @('id', 'displayName', 'appId', 'appOwnerOrganizationId')
        )

        $ForeignPrincipals = @(
            $BlueprintPrincipals | Where-Object {
                $OwnerOrg = [string]$_.appOwnerOrganizationId
                ![string]::IsNullOrWhiteSpace($OwnerOrg) -and $OwnerOrg -ne $CurrentTenantId
            }
        )

        Write-Verbose "Found $($BlueprintPrincipals.Count) Blueprint Principals ($($ForeignPrincipals.Count) foreign)."

        if ($ForeignPrincipals.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No foreign or multi-tenant Agent Blueprint Principals were found in the tenant.'
            )
            return $true
        }

        Write-Verbose 'Reading directory role assignments.'
        $RoleAssignments = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'roleManagement/directory/roleAssignments' `
                -Select @('principalId', 'roleDefinitionId', 'directoryScopeId')
        )
        $RoleDefinitions = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'roleManagement/directory/roleDefinitions' `
                -Select @('id', 'displayName')
        )

        $RoleDefLookup = @{}
        foreach ($Def in $RoleDefinitions) {
            $RoleDefLookup[[string]$Def.id] = $Def
        }

        # Index assignments by principal ID
        $AssignmentsByPrincipal = @{}
        foreach ($Assignment in $RoleAssignments) {
            $AssignedPrincipalId = [string]$Assignment.principalId
            if (![string]::IsNullOrWhiteSpace($AssignedPrincipalId)) {
                if (!$AssignmentsByPrincipal.ContainsKey($AssignedPrincipalId)) {
                    $AssignmentsByPrincipal[$AssignedPrincipalId] = [System.Collections.Generic.List[object]]::new()
                }
                $AssignmentsByPrincipal[$AssignedPrincipalId].Add($Assignment)
            }
        }

        # Read Agent Identities to correlate children of foreign blueprints
        $AgentIdentities = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'displayName', 'agentIdentityBlueprintId', 'appId')
        )

        $ForeignAppIds = @{}
        foreach ($FP in $ForeignPrincipals) {
            $AppId = [string]$FP.appId
            if (![string]::IsNullOrWhiteSpace($AppId)) {
                $ForeignAppIds[$AppId] = $FP
            }
        }

        # $ForeignFindings drives pass/fail: a foreign object holding a role Maester's own
        # built-in-roles catalog (Get-MtRoleInfo) classifies as privileged. isPrivileged is not
        # a Graph-queryable property on unifiedRoleDefinition -- confirmed live, Graph returns
        # 400 Bad Request for it in $select. $PermissionObservations is informational only --
        # application permissions are reported for review, not classified as dangerous, until a
        # shared known-dangerous-permission catalog exists (see Test-MtHighRiskAppPermissions for
        # the equivalent precedent).
        $ForeignFindings = [System.Collections.Generic.List[pscustomobject]]::new()
        $PermissionObservations = [System.Collections.Generic.List[pscustomobject]]::new()
        $RoleObservations = [System.Collections.Generic.List[pscustomobject]]::new()

        # 1. Check foreign Blueprint Principals directly
        foreach ($FP in $ForeignPrincipals) {
            $PrincipalId = [string]$FP.id
            if ($AssignmentsByPrincipal.ContainsKey($PrincipalId)) {
                foreach ($Assigned in $AssignmentsByPrincipal[$PrincipalId]) {
                    $DefId = [string]$Assigned.roleDefinitionId
                    $RoleDef = if ($RoleDefLookup.ContainsKey($DefId)) { $RoleDefLookup[$DefId] } else { $null }
                    if ($null -eq $RoleDef) {
                        $RoleObservations.Add([pscustomobject]@{
                                ObjectId = $PrincipalId
                                DisplayName = [string]$FP.displayName
                                ObjectType = 'Blueprint Principal'
                                RoleName = "Unresolved role definition ($DefId)"
                            })
                        continue
                    }
                    $RoleInfo = Get-MtRoleInfo -RoleName ([string]$RoleDef.displayName -replace '\s', '')
                    if ($null -eq $RoleInfo) {
                        $RoleObservations.Add([pscustomobject]@{
                                ObjectId = $PrincipalId
                                DisplayName = [string]$FP.displayName
                                ObjectType = 'Blueprint Principal'
                                RoleName = [string]$RoleDef.displayName
                            })
                        continue
                    }
                    if (!$RoleInfo.IsPrivileged) { continue }

                    $ForeignFindings.Add([pscustomobject]@{
                        ObjectId       = $PrincipalId
                        DisplayName    = [string]$FP.displayName
                        ObjectType     = 'Blueprint Principal'
                        ForeignTenant  = [string]$FP.appOwnerOrganizationId
                        PrivilegeType  = 'Entra Directory Role'
                        PrivilegeName  = [string]$RoleDef.displayName
                    })
                }
            }

            # Application permissions are recorded as an observation only; presence of a
            # permission alone is not classified as dangerous without a pinned catalog.
            $AppRoles = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                    -RelativeUri "servicePrincipals/$PrincipalId/appRoleAssignments" `
                    -Select @('id', 'resourceDisplayName', 'appRoleId')
            )
            if ($AppRoles.Count -gt 0) {
                $ResourceNames = ($AppRoles.resourceDisplayName | Where-Object { $_ } | Select-Object -Unique) -join ', '
                $PermissionObservations.Add([pscustomobject]@{
                    ObjectId      = $PrincipalId
                    DisplayName   = [string]$FP.displayName
                    ObjectType    = 'Blueprint Principal'
                    ForeignTenant = [string]$FP.appOwnerOrganizationId
                    Count         = $AppRoles.Count
                    Resources     = $ResourceNames
                })
            }
        }

        # 2. Check child Agent Identities under foreign blueprints
        foreach ($AI in $AgentIdentities) {
            $ParentAppId = [string]$AI.agentIdentityBlueprintId
            if (![string]::IsNullOrWhiteSpace($ParentAppId) -and $ForeignAppIds.ContainsKey($ParentAppId)) {
                $IdentityId = [string]$AI.id
                $ParentFP = $ForeignAppIds[$ParentAppId]

                if ($AssignmentsByPrincipal.ContainsKey($IdentityId)) {
                    foreach ($Assigned in $AssignmentsByPrincipal[$IdentityId]) {
                        $DefId = [string]$Assigned.roleDefinitionId
                        $RoleDef = if ($RoleDefLookup.ContainsKey($DefId)) { $RoleDefLookup[$DefId] } else { $null }
                        if ($null -eq $RoleDef) {
                            $RoleObservations.Add([pscustomobject]@{
                                    ObjectId = $IdentityId
                                    DisplayName = [string]$AI.displayName
                                    ObjectType = 'Agent Identity'
                                    RoleName = "Unresolved role definition ($DefId)"
                                })
                            continue
                        }
                        $NormalizedRoleName = [string]$RoleDef.displayName -replace '\s', ''
                        $RoleInfo = Get-MtRoleInfo -RoleName $NormalizedRoleName
                        if ($null -eq $RoleInfo) {
                            $RoleObservations.Add([pscustomobject]@{
                                    ObjectId = $IdentityId
                                    DisplayName = [string]$AI.displayName
                                    ObjectType = 'Agent Identity'
                                    RoleName = [string]$RoleDef.displayName
                                })
                            continue
                        }
                        if (!$RoleInfo.IsPrivileged) { continue }

                        $ForeignFindings.Add([pscustomobject]@{
                            ObjectId      = $IdentityId
                            DisplayName   = [string]$AI.displayName
                            ObjectType    = 'Agent Identity'
                            ForeignTenant = [string]$ParentFP.appOwnerOrganizationId
                            PrivilegeType = 'Entra Directory Role'
                            PrivilegeName = [string]$RoleDef.displayName
                        })
                    }
                }
            }
        }

        $ObservationNote = ''
        if ($RoleObservations.Count -gt 0) {
            $ObservationNote = "`n`nObservation: $($RoleObservations.Count) directory role " +
                'assignment(s) could not be classified by Maester and require review.'
            $ObservationNote += "`n`n| Object ID | Display name | Object type | Directory role |"
            $ObservationNote += "`n| --- | --- | --- | --- |"
            foreach ($Item in $RoleObservations) {
                $DisplayName = [System.Net.WebUtility]::HtmlEncode(
                    [string]$Item.DisplayName
                ) -replace '\|', '&#124;'
                if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
                $RoleName = [System.Net.WebUtility]::HtmlEncode(
                    [string]$Item.RoleName
                ) -replace '\|', '&#124;'
                $ObservationNote += "`n| $($Item.ObjectId) | $DisplayName | " +
                    "$($Item.ObjectType) | $RoleName |"
            }
        }
        if ($PermissionObservations.Count -gt 0) {
            $ObservationNote += "`n`nObservation: $($PermissionObservations.Count) foreign " +
                'Blueprint Principal(s) also hold application permissions. ' +
                'Presence of a permission alone is not flagged as a finding; review for least privilege.' +
                "`n`n| Object ID | Display name | Foreign tenant ID | Permission count | Resources |"
            $ObservationNote += "`n| --- | --- | --- | --- | --- |"
            foreach ($Item in $PermissionObservations) {
                $DisplayName = [string]$Item.DisplayName
                if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
                $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
                $Resources = [System.Net.WebUtility]::HtmlEncode([string]$Item.Resources) -replace '\|', '&#124;'
                $ObservationNote += "`n| $($Item.ObjectId) | $DisplayName | " +
                    "$($Item.ForeignTenant) | $($Item.Count) | $Resources |"
            }
        }

        if ($ForeignFindings.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                "Well done. Found $($ForeignPrincipals.Count) foreign Blueprint Principal(s), but none hold privileged directory roles.$ObservationNote"
            )
            return $true
        }

        $Result = "Found $($ForeignFindings.Count) foreign Agent ID object(s) with privileged Entra directory roles."
        $Result += "`n`n| Object ID | Display name | Object type | Foreign tenant ID | Privilege type | Privilege name |"
        $Result += "`n| --- | --- | --- | --- | --- | --- |"
        foreach ($Item in $ForeignFindings) {
            $DisplayName = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
            $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
            $DisplayName = $DisplayName -replace "`r?`n", ' '
            $PrivName = [System.Net.WebUtility]::HtmlEncode([string]$Item.PrivilegeName) -replace '\|', '&#124;'
            $Result += "`n| $($Item.ObjectId) | $DisplayName | $($Item.ObjectType) | " +
                "$($Item.ForeignTenant) | $($Item.PrivilegeType) | $PrivName |"
        }
        $Result += $ObservationNote

        Add-MtTestResultDetail -Result $Result -Severity 'High'
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
