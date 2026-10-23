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

    # Exchange application roles whose Microsoft Graph permissions differ from the role name, from the
    # Supported Application Roles table in Microsoft's RBAC for Applications documentation. Other roles
    # map to the Graph permission of the same name ('Application Mail.Read' -> 'Mail.Read').
    $roleToGraphPermissions = @{
        'Application MailboxFolder.Read'         = @('MailboxFolder.Read.All')
        'Application MailboxFolder.ReadWrite'    = @('MailboxFolder.ReadWrite.All')
        'Application MailboxItem.Read'           = @('MailboxItem.Read.All')
        'Application MailboxItem.ReadWrite'      = @('MailboxItem.ReadWrite.All')
        'Application MailboxItem.Export'         = @('MailboxItem.Export.All')
        'Application MailboxItem.ImportExport'   = @('MailboxItem.ImportExport.All')
        'Application Mail Full Access'           = @('Mail.ReadWrite', 'Mail.Send')
        'Application Exchange Full Access'       = @('Mail.ReadWrite', 'Mail.Send', 'MailboxSettings.ReadWrite', 'Calendars.ReadWrite', 'Contacts.ReadWrite')
    }

    # An Application Access Policy with RestrictAccess limits an app's Entra grant to a set of mailboxes,
    # so for those apps the Entra grant does not cover every mailbox. They are listed for review, not failed.
    $restrictedAppIds = @()
    try {
        $restrictedAppIds = @(Get-ApplicationAccessPolicy -ErrorAction Stop |
                Where-Object { $_.AccessRight -eq 'RestrictAccess' } |
                ForEach-Object { [string]$_.AppId })
    } catch {
        if ($_.Exception.Message -notlike "*couldn't be found*") { throw }
    }

    # Map Microsoft Graph application permission IDs to their names, for example Mail.Read.
    $msGraph = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
    $graphRoleNames = @{}
    foreach ($appRole in @($msGraph.appRoles)) {
        $graphRoleNames[[string]$appRole.id] = $appRole.value
    }

    $findings = @()
    $restrictedFindings = @()
    foreach ($appGroup in ($assignments | Group-Object -Property { [string]$_.App })) {
        $servicePrincipalId = $appGroup.Name

        # The App value on an Exchange assignment is the service principal's object ID in Microsoft Entra ID.
        $servicePrincipal = Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$servicePrincipalId"
        $graphPermissions = @(Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$servicePrincipalId/appRoleAssignments" |
                Where-Object { $_.resourceId -eq $msGraph.id } |
                ForEach-Object { $graphRoleNames[[string]$_.appRoleId] })

        foreach ($assignment in $appGroup.Group) {
            $rolePermissions = if ($roleToGraphPermissions.ContainsKey([string]$assignment.Role)) {
                $roleToGraphPermissions[[string]$assignment.Role]
            } else {
                @($assignment.Role -replace '^Application ', '')
            }
            # Roles with no Graph twin, such as 'Application EWS.AccessAsApp', never match and are skipped.
            $overlapping = @($rolePermissions | Where-Object { $_ -in $graphPermissions })
            if ($overlapping.Count -eq 0) { continue }

            $scope = @($assignment.CustomResourceScope, $assignment.RecipientAdministrativeUnitScope, $assignment.RecipientGroupScope) |
                Where-Object { $_ } | Select-Object -First 1
            if (-not $scope) { $scope = 'None (organization)' }

            foreach ($permission in $overlapping) {
                $finding = [PSCustomObject]@{
                    Id          = $servicePrincipal.id
                    DisplayName = $servicePrincipal.displayName
                    AppId       = $servicePrincipal.appId
                    Permission  = $permission
                    Scope       = [string]$scope
                }
                if ([string]$servicePrincipal.appId -in $restrictedAppIds) {
                    $restrictedFindings += $finding
                } else {
                    $findings += $finding
                }
            }
        }
    }

    # Apps whose Entra grant is limited by an Application Access Policy, listed for review.
    $restrictedResult = ''
    if ($restrictedFindings.Count -gt 0) {
        $restrictedResult = "`n`nThese apps also hold the permission in Microsoft Entra ID, but an Application Access Policy limits that grant to a set of mailboxes, so they are not counted as failures. Review that the policy scope is no broader than the Exchange scope, and plan to move to RBAC for Applications, which replaces Application Access Policies.`n`n"
        $restrictedResult += "| Application | Application ID | Permission | Exchange scope |`n"
        $restrictedResult += "| --- | --- | --- | --- |`n"
        foreach ($finding in ($restrictedFindings | Sort-Object -Property DisplayName, Permission)) {
            $portalLink = Get-MtLinkServicePrincipal -ServicePrincipal $finding -Blade Permissions
            $restrictedResult += "| $portalLink | $($finding.AppId) | $($finding.Permission) | $($finding.Scope) |`n"
        }
    }

    if ($findings.Count -eq 0) {
        Add-MtTestResultDetail -Result ("Well done. None of the **$(@($assignments.App | Select-Object -Unique).Count)** apps with Exchange RBAC for Applications assignments also hold the same permission tenant-wide in Microsoft Entra ID." + $restrictedResult)
        return $true
    }

    $result = "These apps hold the same permission through a scoped Exchange RBAC assignment and a tenant-wide Microsoft Graph grant in Microsoft Entra ID. The Entra grant covers every mailbox, so the Exchange scope has no effect.`n`n"
    $result += "| Application | Application ID | Permission | Exchange scope with no effect |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($finding in ($findings | Sort-Object -Property DisplayName, Permission)) {
        $portalLink = Get-MtLinkServicePrincipal -ServicePrincipal $finding -Blade Permissions
        $result += "| $portalLink | $($finding.AppId) | $($finding.Permission) | $($finding.Scope) |`n"
    }

    Add-MtTestResultDetail -Result ($result + $restrictedResult)
    return $false
}
