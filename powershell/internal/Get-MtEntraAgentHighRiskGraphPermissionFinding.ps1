function Get-MtEntraAgentHighRiskGraphPermissionFinding {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $RiskPaths = @{
        'AdministrativeUnit.ReadWrite.All'                      = 'Indirect'
        'DeviceManagementConfiguration.ReadWrite.All'          = 'Indirect'
        'DeviceManagementRBAC.ReadWrite.All'                   = 'Indirect'
        'Policy.ReadWrite.ConditionalAccess'                   = 'Direct'
        'PrivilegedAccess.ReadWrite.AzureADGroup'              = 'Direct'
        'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup'  = 'Direct'
        'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup' = 'Indirect'
        'RoleAssignmentSchedule.ReadWrite.Directory'           = 'Direct'
        'RoleEligibilitySchedule.ReadWrite.Directory'          = 'Indirect'
        'RoleManagementPolicy.ReadWrite.AzureADGroup'          = 'Indirect'
        'RoleManagementPolicy.ReadWrite.Directory'             = 'Indirect'
    }
    $AgentIdentities = @(
        Invoke-MtGraphRequest -ApiVersion 'v1.0' `
            -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
            -Select @('id', 'displayName', 'appId')
    )
    if ($AgentIdentities.Count -eq 0) {
        return [pscustomobject]@{ AgentCount = 0; Findings = @() }
    }

    $MicrosoftGraphAppId = '00000003-0000-0000-c000-000000000000'
    $GraphServicePrincipals = @(
        Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals' `
            -Filter "appId eq '$MicrosoftGraphAppId'" -Select @('id', 'appRoles')
    )
    if ($GraphServicePrincipals.Count -ne 1) {
        $Message = 'Expected one Microsoft Graph service principal, found ' +
            "$($GraphServicePrincipals.Count)."
        throw $Message
    }

    $GraphServicePrincipal = $GraphServicePrincipals[0]
    $GraphServicePrincipalId = [string]$GraphServicePrincipal.id
    $RiskyAppRolesById = @{}
    foreach ($AppRole in @($GraphServicePrincipal.appRoles)) {
        $PermissionName = [string]$AppRole.value
        if ($RiskPaths.ContainsKey($PermissionName)) {
            $RiskyAppRolesById[[string]$AppRole.id] = $PermissionName
        }
    }

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Agent in $AgentIdentities) {
        $AgentId = [string]$Agent.id
        $Assignments = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri "servicePrincipals/$AgentId/appRoleAssignments" `
                -Select @('appRoleId', 'resourceId')
        )
        foreach ($Assignment in $Assignments) {
            $AppRoleId = [string]$Assignment.appRoleId
            if ([string]$Assignment.resourceId -eq $GraphServicePrincipalId -and
                $RiskyAppRolesById.ContainsKey($AppRoleId)) {
                $PermissionName = $RiskyAppRolesById[$AppRoleId]
                $Findings.Add([pscustomobject]@{
                        AgentId        = $AgentId
                        DisplayName    = [string]$Agent.displayName
                        AppId          = [string]$Agent.appId
                        Permission     = $PermissionName
                        PermissionType = 'Application'
                        AttackPath     = $RiskPaths[$PermissionName]
                    })
            }
        }

        $Grants = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri "servicePrincipals/$AgentId/oauth2PermissionGrants" `
                -Select @('resourceId', 'scope')
        )
        foreach ($Grant in $Grants) {
            if ([string]$Grant.resourceId -ne $GraphServicePrincipalId) { continue }
            $GrantedScopes = @([string]$Grant.scope -split '\s+' | Where-Object { $_ })
            foreach ($PermissionName in $GrantedScopes) {
                if ($RiskPaths.ContainsKey($PermissionName)) {
                    $Findings.Add([pscustomobject]@{
                            AgentId        = $AgentId
                            DisplayName    = [string]$Agent.displayName
                            AppId          = [string]$Agent.appId
                            Permission     = $PermissionName
                            PermissionType = 'Delegated'
                            AttackPath     = $RiskPaths[$PermissionName]
                        })
                }
            }
        }
    }

    return [pscustomobject]@{ AgentCount = $AgentIdentities.Count; Findings = @($Findings) }
}
