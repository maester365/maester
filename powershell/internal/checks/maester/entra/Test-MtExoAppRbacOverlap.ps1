function Test-MtExoAppRbacOverlap {
    <#
    .SYNOPSIS
    Checks that apps scoped with Exchange RBAC for Applications don't also hold the same or a broader permission tenant-wide in Microsoft Entra ID.

    .DESCRIPTION
    RBAC for Applications in Exchange Online grants an app a permission, such as Mail.Read, scoped to a set of mailboxes.
    Permissions granted in Exchange and in Microsoft Entra ID add together. If the app also holds the same Microsoft Graph
    application permission in Entra ID, or a broader one that includes it such as Mail.ReadWrite, that grant covers every
    mailbox, so the Exchange scope has no effect.

    .EXAMPLE
    Test-MtExoAppRbacOverlap

    Returns true if no app holds the same or a broader permission through both an Exchange RBAC assignment and a tenant-wide Microsoft Graph grant.

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
        'Application MailboxFolder.Read'        = @('MailboxFolder.Read.All')
        'Application MailboxFolder.ReadWrite'   = @('MailboxFolder.ReadWrite.All')
        'Application MailboxItem.Read'          = @('MailboxItem.Read.All')
        'Application MailboxItem.ReadWrite'     = @('MailboxItem.ReadWrite.All')
        'Application MailboxItem.Export'        = @('MailboxItem.Export.All')
        'Application MailboxItem.ImportExport'  = @('MailboxItem.ImportExport.All')
        'Application Mail Full Access'          = @('Mail.ReadWrite', 'Mail.Send')
        'Application Exchange Full Access'      = @('Mail.ReadWrite', 'Mail.Send', 'MailboxSettings.ReadWrite', 'Calendars.ReadWrite', 'Contacts.ReadWrite')
    }

    # Microsoft Graph permissions that include the access of another permission, so a tenant-wide grant of the
    # broader one also covers every mailbox for the narrower one. Each pair is the read/write form of the same
    # permission, per the role descriptions in Microsoft's RBAC for Applications documentation.
    $graphPermissionCovers = @{
        'Mail.ReadWrite'              = @('Mail.Read', 'Mail.ReadBasic')
        'Mail.Read'                   = @('Mail.ReadBasic')
        'Mail.ReadBasic.All'          = @('Mail.ReadBasic')
        'MailboxSettings.ReadWrite'   = @('MailboxSettings.Read')
        'Calendars.ReadWrite'         = @('Calendars.Read')
        'Contacts.ReadWrite'          = @('Contacts.Read')
        'MailboxFolder.ReadWrite.All' = @('MailboxFolder.Read.All')
        'MailboxItem.ReadWrite.All'   = @('MailboxItem.Read.All')
        'MailboxConfigItem.ReadWrite' = @('MailboxConfigItem.Read')
    }

    # Microsoft Graph permissions an Application Access Policy can restrict, from Microsoft's Application Access
    # Policies documentation. A policy has no effect on any other permission.
    $policySupportedPermissions = @(
        'Mail.Read', 'Mail.ReadBasic', 'Mail.ReadBasic.All', 'Mail.ReadWrite', 'Mail.Send',
        'MailboxSettings.Read', 'MailboxSettings.ReadWrite',
        'Calendars.Read', 'Calendars.ReadWrite',
        'Contacts.Read', 'Contacts.ReadWrite'
    )

    # An Application Access Policy with RestrictAccess limits an app's Entra grant to a set of mailboxes,
    # so for those apps a policy-supported Entra grant does not cover every mailbox. They are listed for review, not failed.
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

            $scope = @($assignment.CustomResourceScope, $assignment.RecipientAdministrativeUnitScope, $assignment.RecipientGroupScope) |
                Where-Object { $_ } | Select-Object -First 1
            # An assignment with no resource scope already covers every mailbox in Exchange, so there is no scope to undo.
            if (-not $scope) { continue }

            foreach ($permission in $rolePermissions) {
                # Tenant-wide grants that give at least this access: the same permission, or a broader one that includes it.
                # Roles with no Graph twin, such as 'Application EWS.AccessAsApp', never match and are skipped.
                $coveringGrants = @($graphPermissions | Where-Object { $_ -eq $permission -or $permission -in $graphPermissionCovers[$_] })

                foreach ($grant in $coveringGrants) {
                    $finding = [PSCustomObject]@{
                        Id          = $servicePrincipal.id
                        DisplayName = $servicePrincipal.displayName
                        AppId       = $servicePrincipal.appId
                        Permission  = $permission
                        GraphGrant  = $grant
                        Scope       = [string]$scope
                    }
                    # A policy only limits the Entra grant if it supports that permission.
                    if ([string]$servicePrincipal.appId -in $restrictedAppIds -and $grant -in $policySupportedPermissions) {
                        $restrictedFindings += $finding
                    } else {
                        $findings += $finding
                    }
                }
            }
        }
    }

    # Apps whose Entra grant is limited by an Application Access Policy, listed for review.
    $restrictedResult = ''
    if ($restrictedFindings.Count -gt 0) {
        $restrictedResult = "`n`nThese apps also hold the permission in Microsoft Entra ID, but an Application Access Policy limits that grant to a set of mailboxes, so they are not counted as failures. Review that the policy scope is no broader than the Exchange scope, and plan to move to RBAC for Applications, which replaces Application Access Policies.`n`n"
        $restrictedResult += "| Application | Application ID | Exchange permission | Entra grant | Exchange scope |`n"
        $restrictedResult += "| --- | --- | --- | --- | --- |`n"
        foreach ($finding in ($restrictedFindings | Sort-Object -Property DisplayName, Permission, GraphGrant)) {
            $portalLink = Get-MtLinkServicePrincipal -ServicePrincipal $finding -Blade Permissions
            $restrictedResult += "| $portalLink | $($finding.AppId) | $($finding.Permission) | $($finding.GraphGrant) | $($finding.Scope) |`n"
        }
    }

    if ($findings.Count -eq 0) {
        Add-MtTestResultDetail -Result ("Well done. None of the **$(@($assignments.App | Select-Object -Unique).Count)** apps with Exchange RBAC for Applications assignments also hold the same or a broader permission tenant-wide in Microsoft Entra ID." + $restrictedResult)
        return $true
    }

    $result = "These apps hold a permission through a scoped Exchange RBAC assignment and the same or a broader permission through a tenant-wide Microsoft Graph grant in Microsoft Entra ID. The Entra grant covers every mailbox, so the Exchange scope has no effect.`n`n"
    $result += "| Application | Application ID | Exchange permission | Entra grant | Exchange scope with no effect |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach ($finding in ($findings | Sort-Object -Property DisplayName, Permission, GraphGrant)) {
        $portalLink = Get-MtLinkServicePrincipal -ServicePrincipal $finding -Blade Permissions
        $result += "| $portalLink | $($finding.AppId) | $($finding.Permission) | $($finding.GraphGrant) | $($finding.Scope) |`n"
    }

    Add-MtTestResultDetail -Result ($result + $restrictedResult)
    return $false
}
