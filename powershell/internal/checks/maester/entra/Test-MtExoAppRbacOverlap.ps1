function Test-MtExoAppRbacOverlap {
    <#
    .SYNOPSIS
    Checks that apps scoped with Exchange RBAC for Applications don't also hold the same permission tenant-wide in Microsoft Entra ID.

    .DESCRIPTION
    RBAC for Applications in Exchange Online grants an app a permission, such as Mail.Read, scoped to a set of mailboxes.
    Permissions granted in Exchange and in Microsoft Entra ID add together. If the app also holds the same Microsoft Graph
    application permission in Entra ID, that grant covers every mailbox, so the Exchange scope has no effect.

    .EXAMPLE
    Test-MtExoAppRbacOverlap

    Returns true if no app holds the same permission through both an Exchange RBAC assignment and a tenant-wide Microsoft Graph grant.

    .LINK
    https://maester.dev/docs/commands/Test-MtExoAppRbacOverlap
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Exchange RBAC assignments made to apps. Role group assignments, such as the built-in delegating
    # assignments to Organization Management, are excluded by the assignee type.
    $assignments = @(Get-ManagementRoleAssignment -RoleAssigneeType ServicePrincipal -ErrorAction Stop |
            Where-Object { $_.Enabled -and $_.Role -like 'Application *' })

    if ($assignments.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. No apps have Exchange RBAC for Applications assignments, so there is no overlap with Microsoft Entra ID grants.'
        return $true
    }

    # Map Microsoft Graph application permission IDs to their names, for example Mail.Read.
    $msGraph = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
    $graphRoleNames = @{}
    foreach ($appRole in @($msGraph.appRoles)) {
        $graphRoleNames[[string]$appRole.id] = $appRole.value
    }

    $findings = @()
    foreach ($appGroup in ($assignments | Group-Object -Property { [string]$_.App })) {
        $servicePrincipalId = $appGroup.Name

        # The App value on an Exchange assignment is the service principal's object ID in Microsoft Entra ID.
        $servicePrincipal = Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$servicePrincipalId"
        $graphPermissions = @(Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$servicePrincipalId/appRoleAssignments" |
                Where-Object { $_.resourceId -eq $msGraph.id } |
                ForEach-Object { $graphRoleNames[[string]$_.appRoleId] })

        foreach ($assignment in $appGroup.Group) {
            # Exchange names each application role after the Graph permission it scopes: 'Application Mail.Read' -> 'Mail.Read'.
            # Roles with no Graph twin, such as 'Application EWS.AccessAsApp', never match and are skipped.
            $permission = $assignment.Role -replace '^Application ', ''
            if ($permission -notin $graphPermissions) { continue }

            $scope = @($assignment.CustomResourceScope, $assignment.RecipientAdministrativeUnitScope, $assignment.RecipientGroupScope) |
                Where-Object { $_ } | Select-Object -First 1
            if (-not $scope) { $scope = 'None (organization)' }

            $findings += [PSCustomObject]@{
                Id          = $servicePrincipal.id
                DisplayName = $servicePrincipal.displayName
                AppId       = $servicePrincipal.appId
                Permission  = $permission
                Scope       = [string]$scope
            }
        }
    }

    if ($findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. None of the **$(@($assignments.App | Select-Object -Unique).Count)** apps with Exchange RBAC for Applications assignments also hold the same permission tenant-wide in Microsoft Entra ID."
        return $true
    }

    $result = "These apps hold the same permission through a scoped Exchange RBAC assignment and a tenant-wide Microsoft Graph grant in Microsoft Entra ID. The Entra grant covers every mailbox, so the Exchange scope has no effect.`n`n"
    $result += "| Application | Application ID | Permission | Exchange scope with no effect |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($finding in ($findings | Sort-Object -Property DisplayName, Permission)) {
        $portalLink = Get-MtLinkServicePrincipal -ServicePrincipal $finding -Blade Permissions
        $result += "| $portalLink | $($finding.AppId) | $($finding.Permission) | $($finding.Scope) |`n"
    }

    Add-MtTestResultDetail -Result $result
    return $false
}
