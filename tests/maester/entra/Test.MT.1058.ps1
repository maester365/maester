function Test-MtSpExchangeAppAccessPolicy {
    <#
    .SYNOPSIS
    Check if service principals with Exchange permissions have application access policies configured.

    .DESCRIPTION
    Service principals with Exchange permissions can access all mailboxes by default. This test verifies that proper access policies are in place.

    .EXAMPLE
    Test-MtSpExchangeAppAccessPolicy

    Returns true if all service principals with Exchange permissions have access policies configured.
    It also returns true when the only finding is an app role assignment that it could not evaluate: that result is marked Investigate in the test result details, not in the return value.

    .LINK
    https://maester.dev/docs/commands/Test-MtSpExchangeAppAccessPolicy
    #>
    [MaesterTest(
        Id = 'MT.1058',
        Title = 'Exchange application access policies must be configured.',
        Product = 'entra',
        RelatedProduct = 'exchange',
        Feature = 'app-consent',
        Area = 'applications',
        ResourceType = 'ServicePrincipal',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1114.002',
        Control = ('nist-800-53-r5:AC-6', 'nist-800-53-r5:AC-3'),
        Service = ('Graph', 'ExchangeOnline'),
        LongRunning,
        Author = 'l-gosling',
        Contributor = ('merill', 'SamErde', 'thomas-s-schmidt', 'julien-ly')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Running Test-MtSpExchangeAppAccessPolicy'

    # Note: If you make any changes to these lists, please keep them in sync
    # with the markdown file Test.MT.1058.md
    # Permissions that application access policies restrict, by the appId of the API that defines them.
    $mailboxApiPermissions = [ordered]@{
        # Microsoft Graph
        '00000003-0000-0000-c000-000000000000' = @(
            'Mail.Read', 'Mail.ReadBasic', 'Mail.ReadBasic.All', 'Mail.ReadWrite', 'Mail.Send',
            'MailboxSettings.Read', 'MailboxSettings.ReadWrite',
            'Calendars.Read', 'Calendars.ReadWrite',
            'Contacts.Read', 'Contacts.ReadWrite'
        )
        # Office 365 Exchange Online: Exchange Web Services (EWS)
        '00000002-0000-0ff1-ce00-000000000000' = @('full_access_as_app')
    }
    $exchangePermissions = @($mailboxApiPermissions.Values | ForEach-Object { $_ })

    # An app role ID is defined by the API the assignment points to (its resourceId), so it is resolved there.
    $mailboxApis = @{}
    foreach ($apiAppId in $mailboxApiPermissions.Keys) {
        foreach ($api in @(Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -Filter "appId eq '$apiAppId'")) {
            $roleValues = @{}
            foreach ($appRole in @($api.AppRoles)) {
                $roleValues[[string]$appRole.Id] = $appRole.Value
            }
            $mailboxApis[[string]$api.Id] = [PSCustomObject]@{
                DisplayName = $api.DisplayName
                RoleValues  = $roleValues
                Permissions = $mailboxApiPermissions[$apiAppId]
            }
        }
    }

    # Get service principals with Exchange permissions
    $unresolvedAssignments = [System.Collections.Generic.List[object]]::new()
    $servicePrincipals = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals'
    $principalsWithExchangePerms = $servicePrincipals | ForEach-Object {
        $sp = $_
        $appRoles = Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$($sp.Id)/appRoleAssignments"
        $permissions = foreach ($assignment in @($appRoles)) {
            $api = $mailboxApis[[string]$assignment.ResourceId]
            # Other APIs, and the default access role (empty GUID), grant no mailbox permission.
            if (-not $api -or $assignment.AppRoleId -eq [guid]::Empty) {
                continue
            }
            $roleId = [string]$assignment.AppRoleId
            if (-not $api.RoleValues.ContainsKey($roleId)) {
                $unresolvedAssignments.Add([PSCustomObject]@{ ServicePrincipal = $sp; Api = $api.DisplayName; AppRoleId = $roleId })
            } elseif ($api.RoleValues[$roleId] -in $api.Permissions) {
                $api.RoleValues[$roleId]
            }
        }

        if ($permissions) {
            [PSCustomObject]@{
                Id          = $sp.Id
                DisplayName = $sp.DisplayName
                AppId       = $sp.AppId
                Permissions = $permissions -join ', '
            }
        }
    }

    # Get application access policies
    try {
        $appAccessPolicies = Get-ApplicationAccessPolicy -ErrorAction Stop |
            Where-Object { $_.AccessRight -eq 'RestrictAccess' }
    } catch {
        # Exchange REST preserves the server exception type even when its message is localized.
        $remoteException = $_.Exception.Data['RemoteException']
        $policyNotFound = $remoteException -and $remoteException.PSObject.Properties['TypeName'] -and
            $remoteException.TypeName -eq 'Microsoft.Exchange.Configuration.Tasks.ManagementObjectNotFoundException'
        if ($policyNotFound -or $_.Exception.Message -like "*couldn't be found*") {
            Write-Verbose -Message 'Test-MtSpExchangeAppAccessPolicy: No application access policies were found.'
            $appAccessPolicies = $null
        } else {
            throw
        }
    }

    $missingPolicies = @()
    $appsWithPolicies = @()
    foreach ($sp in $principalsWithExchangePerms) {
        $hasPolicy = $appAccessPolicies.AppId -contains $sp.AppId
        $filteredPermissions = $sp.Permissions -split ', ' | Where-Object { $_ -in $exchangePermissions }
        $appRecord = [PSCustomObject]@{
            Id          = $sp.Id
            DisplayName = $sp.DisplayName
            AppId       = $sp.AppId
            Permissions = $filteredPermissions -join ', '
        }

        if (-not $hasPolicy) {
            $missingPolicies += $appRecord
        } else {
            $appsWithPolicies += $appRecord
        }
    }

    $appsWithExchangePermissionsCount = ($principalsWithExchangePerms | Measure-Object).Count
    $invalidCount = ($missingPolicies | Measure-Object).Count
    $result = $invalidCount -eq 0
    # An assignment that could not be resolved is not evidence of compliance: no failure, but not a pass either.
    $needsReview = $result -and $unresolvedAssignments.Count -gt 0
    $praise = if ($needsReview) { '' } else { 'Well done. ' }

    if ($appsWithExchangePermissionsCount -eq 0) {
        $testResultMarkdown = "${praise}No applications with Exchange permissions were found."
    } elseif ($result) {
        $testResultMarkdown = "${praise}All **$appsWithExchangePermissionsCount** applications with Exchange permissions have matching RestrictAccess policies configured."
    } else {
        $testResultMarkdown = "Found **$appsWithExchangePermissionsCount** applications with Exchange permissions. **$invalidCount** application(s) do not have a matching RestrictAccess policy configured."

        $missingPoliciesMarkdown = "`n`n### Applications Missing Matching RestrictAccess Policies`n`n"
        $missingPoliciesMarkdown += "| Application | Application ID | Exchange Permissions |`n"
        $missingPoliciesMarkdown += "| --- | --- | --- |`n"

        foreach ($app in ($missingPolicies | Sort-Object -Property DisplayName)) {
            $portalLink = Get-MtLinkServicePrincipal -ServicePrincipal $app -Blade Permissions
            $missingPoliciesMarkdown += "| $portalLink | $($app.AppId) | $($app.Permissions) |`n"
        }

        $testResultMarkdown += $missingPoliciesMarkdown
    }

    if ($appsWithPolicies.Count -gt 0 -and $invalidCount -gt 0) {
        $testResultMarkdown += "`n`n**Applications with matching RestrictAccess policies configured:** $($appsWithPolicies.Count)"
    }

    if ($unresolvedAssignments.Count -gt 0) {
        $testResultMarkdown += "`n`n### App Role Assignments Not Evaluated`n`n"
        $testResultMarkdown += "These assignments name an app role that the API does not define, so this check cannot tell what they grant. Review them before reading this result as a pass.`n`n"
        $testResultMarkdown += "| Application | API | App Role ID |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($unresolved in $unresolvedAssignments) {
            $portalLink = Get-MtLinkServicePrincipal -ServicePrincipal $unresolved.ServicePrincipal -Blade Permissions
            $testResultMarkdown += "| $portalLink | $(Get-MtSafeMarkdown $unresolved.Api) | $(Get-MtSafeMarkdown $unresolved.AppRoleId) |`n"
        }
    }

    if ($needsReview) {
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    } else {
        Add-MtTestResultDetail -Result $testResultMarkdown
    }
    return $result
}
