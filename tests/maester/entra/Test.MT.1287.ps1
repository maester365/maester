function Test-MtEntraUserConsentGrant {
    <#
    .SYNOPSIS
    Finds third-party apps that keep the delegated permissions users granted, after user consent is restricted.

    .DESCRIPTION
    Restricting user consent only affects future consents. The delegated permissions that users granted
    before the change remain, and the apps keep accessing data on the users' behalf until an administrator
    revokes the grants.

    This check reads the consent policies assigned to the default user role, then the delegated permission
    grants that users gave for themselves (consent type Principal). It lists the apps that hold such grants,
    except Microsoft first-party apps, apps registered in this tenant, and apps whose sign-in is disabled,
    since tokens aren't issued for them.

    When user consent is turned off, every grant left predates the change, and the test fails. When user
    consent is limited, for example to apps from verified publishers, the current policy may allow some of
    the grants, so the result asks for a review. When users can consent to any app, the grants are expected
    and the test is skipped: EIDSCA.AP08 checks that setting.

    An administrator can also grant consent on behalf of a single user through Microsoft Graph. Such a grant
    looks the same as user consent.

    .EXAMPLE
    Test-MtEntraUserConsentGrant

    .LINK
    https://maester.dev/docs/commands/Test-MtEntraUserConsentGrant

    .LINK
    https://learn.microsoft.com/entra/identity/enterprise-apps/configure-user-consent
    #>
    [MaesterTest(
        Id = 'MT.1287',
        Title = 'User consent grants to third-party apps should not remain after user consent is restricted.',
        Product = 'entra',
        Feature = 'app-consent',
        Area = 'applications',
        ResourceType = 'ServicePrincipal',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1528',
        Control = 'nist-800-53-r5:AC-6',
        Service = 'Graph',
        Author = 'julien-ly'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Tenants where Microsoft registers its first-party apps.
    $MicrosoftTenantIds = @('f8cdef31-a31e-4b4a-93e4-5f571e91255a', '72f988bf-86f1-41af-91ab-2d7cd011db47')
    $TenantId = [string](Get-MgContext).TenantId

    try {
        $UserRolePermissions = (Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'policies/authorizationPolicy').defaultUserRolePermissions
        if ($null -eq $UserRolePermissions) {
            throw 'Could not read the permissions of the default user role from the authorization policy.'
        }
        # Only the ManagePermissionGrantsForSelf policies set what users can consent to for themselves.
        $ConsentPolicies = @(
            $UserRolePermissions.permissionGrantPoliciesAssigned |
                Where-Object { "$_" -like 'ManagePermissionGrantsForSelf.*' } |
                ForEach-Object { "$_".Substring('ManagePermissionGrantsForSelf.'.Length) }
        )
        if ($ConsentPolicies -contains 'microsoft-user-default-legacy') {
            Add-MtTestResultDetail -SkippedBecause NotApplicable -Result (
                'Users can consent to any app, so the grants they gave are expected. Restrict user consent first: EIDSCA.AP08 checks this setting.'
            )
            return $null
        }

        $Grants = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'oauth2PermissionGrants' -Filter "consentType eq 'Principal'" `
                -Select @('id', 'clientId', 'principalId', 'resourceId', 'scope')
        )
        # Read each client app and each resource API once.
        $ServicePrincipalById = @{}
        $ServicePrincipalIds = @($Grants | ForEach-Object { [string]$_.clientId; [string]$_.resourceId } | Where-Object { $_ } | Sort-Object -Unique)
        if ($ServicePrincipalIds.Count -gt 0) {
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals' -UniqueId $ServicePrincipalIds `
                -Select @('id', 'appId', 'displayName', 'appOwnerOrganizationId', 'verifiedPublisher', 'accountEnabled') |
                ForEach-Object { $ServicePrincipalById[[string]$_.id] = $_ }
        }
    } catch {
        # Graph answers 403 when the signed-in account cannot read the authorization policy, the grants or the apps.
        # Any other error goes to the engine, which reports it.
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 403) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    $UserIds = [System.Collections.Generic.HashSet[string]]::new()
    $Findings = @(
        foreach ($ClientGrants in ($Grants | Group-Object -Property { [string]$_.clientId })) {
            $Client = $ServicePrincipalById[[string]$ClientGrants.Name]
            if ($null -eq $Client) { continue }
            # Microsoft first-party apps and apps registered in this tenant are not third-party apps.
            # Tokens aren't issued for an app whose sign-in is disabled, so its grants are not used.
            $OwnerTenantId = [string]$Client.appOwnerOrganizationId
            if ($OwnerTenantId -in $MicrosoftTenantIds -or ($TenantId -and $OwnerTenantId -eq $TenantId) -or $Client.accountEnabled -eq $false) {
                continue
            }

            $Permissions = foreach ($ResourceGrants in ($ClientGrants.Group | Group-Object -Property { [string]$_.resourceId })) {
                $Resource = $ServicePrincipalById[[string]$ResourceGrants.Name]
                $ResourceName = if ($Resource -and $Resource.displayName) { [string]$Resource.displayName } else { [string]$ResourceGrants.Name }
                $Scopes = @($ResourceGrants.Group | ForEach-Object { "$($_.scope)" -split '\s+' } | Where-Object { $_ } | Sort-Object -Unique)
                if ($Scopes.Count -gt 0) { "$($ResourceName): $($Scopes -join ', ')" }
            }
            $AppUserIds = @($ClientGrants.Group | ForEach-Object { [string]$_.principalId } | Where-Object { $_ } | Sort-Object -Unique)
            foreach ($UserId in $AppUserIds) { [void]$UserIds.Add($UserId) }

            [pscustomobject]@{
                ServicePrincipal = $Client
                Publisher        = if ($Client.verifiedPublisher) { [string]$Client.verifiedPublisher.displayName } else { '' }
                Users            = $AppUserIds.Count
                Permissions      = @($Permissions | Sort-Object) -join '; '
            }
        }
    )

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. No third-party app holds delegated permissions that users granted for themselves.'
        return $true
    }

    $Findings = @($Findings | Sort-Object -Property @{ Expression = { $_.Users }; Descending = $true }, @{ Expression = { [string]$_.ServicePrincipal.displayName } })
    $Table = "| App | Verified publisher | Users | Delegated permissions |`n| --- | --- | --- | --- |"
    foreach ($Item in $Findings) {
        $App = Get-MtLinkServicePrincipal -ServicePrincipal $Item.ServicePrincipal -Blade Permissions
        $Publisher = if ($Item.Publisher) { Get-MtSafeMarkdown -Text $Item.Publisher } else { 'None' }
        $Table += "`n| $App | $Publisher | $($Item.Users) | $(Get-MtSafeMarkdown -Text $Item.Permissions) |"
    }

    if ($ConsentPolicies.Count -eq 0) {
        $Result = "User consent is turned off, but $($Findings.Count) third-party app(s) still hold delegated permissions that $($UserIds.Count) user(s) granted for themselves. "
        $Result += 'Turning off user consent only blocks new consents: these grants keep working until you revoke them.'
        Add-MtTestResultDetail -Result "$Result`n`n$Table"
        return $false
    }

    $PolicyList = ($ConsentPolicies | ForEach-Object { "``$_``" }) -join ', '
    $Result = "User consent is limited by $PolicyList. $($Findings.Count) third-party app(s) hold delegated permissions that $($UserIds.Count) user(s) granted for themselves. "
    $Result += 'Grants given before the restriction keep working: check that the current policy allows them, and revoke the others.'
    Add-MtTestResultDetail -Result "$Result`n`n$Table" -Investigate
    return $true
}
