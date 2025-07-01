<#
.SYNOPSIS
    Check if any applications or service principals have high risk Graph permissions that can lead to direct or indirect paths
    to Global Admin and full tenant takeover. The permissions are based on the research published at https://github.com/emiliensocchi/azure-tiering/tree/main.

.DESCRIPTION
    Applications that use Graph API permissions with a risk of having a direct or indirect path to Global Admin and full tenant takeover.

.EXAMPLE
    Test-MtHighRiskAppPermissions

    Returns true if no application has Tier-0 graph permissions

.LINK
    https://maester.dev/docs/commands/Test-MtHighRiskAppPermissions
#>
function Test-MtHighRiskAppPermissions {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple permissions.')]
    [OutputType([bool])]
    param(
        # Check for direct path to Global Admin or indirect path through a combination of permissions. Default is "All".
        [ValidateSet('All', 'Direct', 'Indirect')]
        [String] $AttackPath = 'All'
    )

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $allCriticalGraphPermissions = @(
        [pscustomobject]@{
            Id   = '2f6817f8-7b12-4f0f-bc18-eeaf60705a9e'
            Name = 'PrivilegedAccess.ReadWrite.AzureADGroup'
            Type = 'Application'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = '32531c59-1f32-461f-b8df-6f8a3b89f73b'
            Name = 'PrivilegedAccess.ReadWrite.AzureADGroup'
            Type = 'Delegated'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = '41202f2c-f7ab-45be-b001-85c9728b9d69'
            Name = 'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup'
            Type = 'Application'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = '06dbc45d-6708-4ef0-a797-f797ee68bf4b'
            Name = 'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup'
            Type = 'Delegated'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = 'dd199f4a-f148-40a4-a2ec-f0069cc799ec'
            Name = 'RoleAssignmentSchedule.ReadWrite.Directory'
            Type = 'Application'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = '8c026be3-8e26-4774-9372-8d5d6f21daff'
            Name = 'RoleAssignmentSchedule.ReadWrite.Directory'
            Type = 'Delegated'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = '9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8'
            Name = 'RoleManagement.ReadWrite.Directory'
            Type = 'Application'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = 'd01b97e9-cbc0-49fe-810a-750afd5527a3'
            Name = 'RoleManagement.ReadWrite.Directory'
            Type = 'Delegated'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = 'eccc023d-eccf-4e7b-9683-8813ab36cecc'
            Name = 'User.DeleteRestore.All'
            Type = 'Application'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = '4bb440cd-2cf2-4f90-8004-aa2acd2537c5'
            Name = 'User.DeleteRestore.All'
            Type = 'Delegated'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = '3011c876-62b7-4ada-afa2-506cbbecc68c'
            Name = 'User.EnableDisableAccount.All'
            Type = 'Application'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = 'f92e74e7-2563-467f-9dd0-902688cb5863'
            Name = 'User.EnableDisableAccount.All'
            Type = 'Delegated'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = '50483e42-d915-4231-9639-7fdb7fd190e5'
            Name = 'UserAuthenticationMethod.ReadWrite.All'
            Type = 'Application'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = 'b7887744-6746-4312-813d-72daeaee7e2d'
            Name = 'UserAuthenticationMethod.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = '5eb59dd3-1da2-4329-8733-9dabdc435916'
            Name = 'AdministrativeUnit.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '7b8a2d34-6b3f-4542-a343-54651608ad81'
            Name = 'AdministrativeUnit.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9'
            Name = 'Application.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'bdfbf15f-ee85-4955-8675-146e8e5296b5'
            Name = 'Application.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '18a4783c-866b-4cc7-a460-3d5e5662c884'
            Name = 'Application.ReadWrite.OwnedBy'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '06b708a9-e830-4db3-a914-8e69da51d44f'
            Name = 'AppRoleAssignment.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '84bccea3-f856-4a8a-967b-dbe0a3d53a64'
            Name = 'AppRoleAssignment.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '9241abd9-d0e6-425a-bd4f-47ba86e767a4'
            Name = 'DeviceManagementConfiguration.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '0883f392-0a7a-443d-8c76-16a6d39c7b63'
            Name = 'DeviceManagementConfiguration.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'e330c4f0-4170-414e-a55a-2f022ec2b57b'
            Name = 'DeviceManagementRBAC.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '0c5e8a55-87a6-4556-93ab-adc52c4d862d'
            Name = 'DeviceManagementRBAC.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '19dbc75e-c2e2-444c-a770-ec69d8559fc7'
            Name = 'Directory.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'c5366453-9fb0-48a5-a156-24f0c49a4b84'
            Name = 'Directory.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '9acd699f-1e81-4958-b001-93b1d2506e19'
            Name = 'EntitlementManagement.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'ae7a573d-81d7-432b-ad44-4ed5c9d89038'
            Name = 'EntitlementManagement.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '62a82d76-70ea-41e2-9197-370581804d09'
            Name = 'Group.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '4e46008b-f24c-477d-8fff-7bb4ec7aafe0'
            Name = 'Group.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'dbaae8cf-10b5-4b86-a4a1-f871c94c6695'
            Name = 'GroupMember.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'f81125ac-d3b7-4573-a3b2-7099cc39df9e'
            Name = 'GroupMember.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '29c18626-4985-4dcd-85c0-193eef327366'
            Name = 'Policy.ReadWrite.AuthenticationMethod'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '7e823077-d88e-468f-a337-e18f1f0e6c7c'
            Name = 'Policy.ReadWrite.AuthenticationMethod'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'a402ca1c-2696-4531-972d-6e5ee4aa11ea'
            Name = 'Policy.ReadWrite.PermissionGrant'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '2672f8bb-fd5e-42e0-85e1-ec764dd2614e'
            Name = 'Policy.ReadWrite.PermissionGrant'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '618b6020-bca8-4de6-99f6-ef445fa4d857'
            Name = 'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'ba974594-d163-484e-ba39-c330d5897667'
            Name = 'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'fee28b28-e1f3-4841-818e-2704dc62245f'
            Name = 'RoleEligibilitySchedule.ReadWrite.Directory'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '62ade113-f8e0-4bf9-a6ba-5acb31db32fd'
            Name = 'RoleEligibilitySchedule.ReadWrite.Directory'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'b38dcc4d-a239-4ed6-aa84-6c65b284f97c'
            Name = 'RoleManagementPolicy.ReadWrite.AzureADGroup'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '0da165c7-3f15-4236-b733-c0b0f6abe41d'
            Name = 'RoleManagementPolicy.ReadWrite.AzureADGroup'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '31e08e0a-d3f7-4ca2-ac39-7343fb83e8ad'
            Name = 'RoleManagementPolicy.ReadWrite.Directory'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '1ff1be21-34eb-448c-9ac9-ce1f506b2a68'
            Name = 'RoleManagementPolicy.ReadWrite.Directory'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '741f803b-c850-494e-b5df-cde7c675a1ca'
            Name = 'User.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '204e0828-b5ca-4ad8-b9f3-f32a958e7cc4'
            Name = 'User.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'cc117bb9-00cf-4eb8-b580-ea2a878fe8f7'
            Name = 'User-PasswordProfile.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '56760768-b641-451f-8906-e1b8ab31bca7'
            Name = 'User-PasswordProfile.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '9241abd9-d0e6-425a-bd4f-47ba86e767a4'
            Name = 'DeviceManagementConfiguration.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '0883f392-0a7a-443d-8c76-16a6d39c7b63'
            Name = 'DeviceManagementConfiguration.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = 'e330c4f0-4170-414e-a55a-2f022ec2b57b'
            Name = 'DeviceManagementRBAC.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '0c5e8a55-87a6-4556-93ab-adc52c4d862d'
            Name = 'DeviceManagementRBAC.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '7e05723c-0bb0-42da-be95-ae9f08a6e53c'
            Name = 'Domain.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '0b5d694c-a244-4bde-86e6-eb5cd07730fe'
            Name = 'Domain.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '292d869f-3427-49a8-9dab-8c70152b74e9'
            Name = 'Organization.ReadWrite.All'
            Type = 'Application'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '46ca0847-7e6b-426e-9775-ea810a948356'
            Name = 'Organization.ReadWrite.All'
            Type = 'Delegated'
            Path = 'Indirect'
        }
        [pscustomobject]@{
            Id   = '01c0a623-fc9b-48e9-b794-0756f8e8f067'
            Name = 'Policy.ReadWrite.ConditionalAccess'
            Type = 'Application'
            Path = 'Direct'
        }
        [pscustomobject]@{
            Id   = 'ad902697-1014-4ef5-81ef-2b4301988e8c'
            Name = 'Policy.ReadWrite.ConditionalAccess'
            Type = 'Delegated'
            Path = 'Direct'
        }
    )

    $return = $true

    Write-Verbose 'Test-MtHighRiskAppPermissions: Checking applications for high-risk permissions'
    try {
        $allApiAssignments = [System.Collections.Generic.List[PSCustomObject]]::new()

        $allServicePrincipals = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals'
        foreach ($sp in $allServicePrincipals) {
            if (([string]::IsNullOrEmpty($sp.Id))) {
                continue
            }
            $spUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($sp.id)/appId/$($sp.appId)"

            $spAppRoleAssignments = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/appRoleAssignments" -Method GET
            $spAppRoleAssignments.value | ForEach-Object {
                $allApiAssignments.Add([PSCustomObject]@{
                        appDisplayName = $sp.appDisplayName
                        objectId       = $sp.Id
                        appId          = $sp.appId
                        appUrl         = $spUrl
                        permissionId   = $_.appRoleId
                        permissionName = $null
                        type           = 'Application'
                    })
            }

            $spOauth2PermissionGrants = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/oauth2PermissionGrants" -Method GET
            $spOauth2PermissionGrants.value | ForEach-Object {
                $_.scope.Split(' ') | ForEach-Object {
                    $allApiAssignments.Add([PSCustomObject]@{
                            appDisplayName = $sp.appDisplayName
                            objectId       = $sp.Id
                            appId          = $sp.appId
                            appUrl         = $spUrl
                            permissionId   = $null
                            permissionName = $_.Trim()
                            type           = 'Delegated'
                        })
                }
            }
        }

        if ($attackPath -ne 'All') {
            $allCriticalGraphPermissionsToCheck = $allCriticalGraphPermissions | Where-Object { $_.Path -eq $attackPath }
            $attackPathStr = $attackPath.ToLower()
        } else {
            $attackPathStr = 'direct or indirect'
            $allCriticalGraphPermissionsToCheck = $allCriticalGraphPermissions
        }

        $allAssignedCriticalPermissions = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($apiAssignment in $allApiAssignments) {
            foreach ($criticalGraphPermission in $allCriticalGraphPermissionsToCheck) {
                $compareAssignment = if ($apiAssignment.type -eq 'Application') { $apiAssignment.permissionId } else { $apiAssignment.permissionName }
                $compareGraphPermission = if ($apiAssignment.type -eq 'Application') { $criticalGraphPermission.Id } else { $criticalGraphPermission.Name }

                if (($compareAssignment -eq $compareGraphPermission) -and ($apiAssignment.type -eq $criticalGraphPermission.Type)) {
                    $allAssignedCriticalPermissions.Add([PSCustomObject]@{
                            ApplicationName = $apiAssignment.appDisplayName
                            ApplicationId   = $apiAssignment.appId
                            ApplicationUrl  = $apiAssignment.appUrl
                            PermissionName  = $criticalGraphPermission.Name
                            PermissionType  = $criticalGraphPermission.Type
                            AttackPath      = $criticalGraphPermission.Path
                        })
                }
            }
        }
        $return = if (($allAssignedCriticalPermissions | Measure-Object).Count -eq 0) { $true } else { $false }

        if ($return) {
            $testResultMarkdown = "Well done. No application has graph permissions with a risk of having a $($attackPathStr) path to Global Admin and full tenant takeover."
        } else {
            $testResultMarkdown = "At least one application has graph permissions with a risk of having a $($attackPathStr) path to Global Admin and full tenant takeover.`n`n%TestResult%"

            $result = "| ApplicationName | ApplicationId | PermissionName | PermissionType | AttackPath |`n"
            $result += "| --- | --- | --- | --- | --- |`n"
            foreach ($assignedCriticalPermission in $allAssignedCriticalPermissions) {
                $appMdLink = "[$($assignedCriticalPermission.ApplicationName)]($($assignedCriticalPermission.ApplicationUrl))"
                $result += "| $($appMdLink) | $($assignedCriticalPermission.ApplicationId) | $($assignedCriticalPermission.PermissionName) | $($assignedCriticalPermission.PermissionType) | $($assignedCriticalPermission.AttackPath) |`n"
            }
            $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
