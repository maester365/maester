<#
.SYNOPSIS
    Executes EntraOps Query Service Principals with High Privileges Roles on Microsoft Graph and delegation by owners

.DESCRIPTION

    Avoid the direct assignment of privileged objects without restricted management to Azure RBAC with High Privileged Roles on Tenant Root or Management Group.

    Queries EntraOps classification data
    and returns and validate if result is $true.

.EXAMPLE
    Test-MtEOPS-04

    Returns the result of Service Principals with High Privileges Roles on Microsoft Graph and delegation by owners
#>

Function Test-MtEOPS-04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    #region Query from EntraOps YAML file
    $SpWithOwners = $EntraOpsPrivilegedEamData `
  | Where-Object {$_.ObjectType -eq "serviceprincipal" -and $_.Classification.AdminTierLevelName -contains "ControlPlane"} `
  | Where-Object {$_.Owners -ne $null}
$SpOwners = $SpWithOwners | ForEach-Object {
    $Owners = $_.Owners | ForEach-Object {
        Get-EntraOpsPrivilegedEntraObject -AadObjectId $_
    }
    [PSCustomObject]@{
        "ObjectId" = $_.ObjectId
        "Owners" = $Owners
    }
}
$QueryResult = $SpWithOwners | ForEach-Object {
      [PSCustomObject]@{
          "ObjectDisplayName"        = $_.ObjectDisplayName
          "ObjectType"               = $_.ObjectType
          "ObjectId"                 = $_.ObjectId
          "SignInName"               = $_.ObjectSignInName
          "RoleDefinitionName"       = "Owners"
          "RoleAssignmentScopeName"  = "servicePrincipal"
          "RoleSystem"               = "Resource"
          "AdminTierLevelName"       = ($_.classification | Sort-Object AdminTierLevel)[0].AdminTierLevelName
          "Description"              = $null
      }
}

    #endregion

    $testResult = ($QueryResult | Measure-Object | Select-Object -ExpandProperty Count) -eq "0"


    #region Add result of EntraOps query to testResultDetails
    if ($testResult) {
        $ResultDescription = "Well done. The result of your EntraOps classification data shows no impacted privileges."
    } else {
        $ResultDescription = "Your EntraOps classification data have findings. The following privileges are affected:"
        if ($QueryResult.Description) {
            $DescriptionIncluded = $true
        } else {
            $DescriptionIncluded = $false
        }

        if($DescriptionIncluded -eq $true) {
            $ImpactedPrivilegesList = "`n`n#### Impacted privileges`n`n | Privileged Object | Privileged Assignment | Description | `n"
            $ImpactedPrivilegesList += "| --- | --- | --- |`n"
        } else {
            $ImpactedPrivilegesList = "`n`n#### Impacted privileges`n`n | Privileged Object | Privileged Assignment | `n"
            $ImpactedPrivilegesList += "| --- | --- | --- |`n"
        }

        foreach ($AffectedPrivileged in $QueryResult) {
            #region PrincipalType icon
            if ($AffectedPrivileged.ObjectType -eq 'user') {
                $ObjectTypeIcon = "👩‍💻"
                $ObjectPortalUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($AffectedPrivileged.ObjectId)"
            } elseif ($AffectedPrivileged.ObjectType -eq 'group') {
                $ObjectTypeIcon = "👥"
                $ObjectPortalUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/$($AffectedPrivileged.ObjectId)"
            } elseif ($AffectedPrivileged.ObjectType -eq 'servicePrincipal') {
                $ObjectTypeIcon = "🤖"
                $ObjectPortalUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($AffectedPrivileged.ObjectId)/appId/$($AffectedPrivileged.SignInName)"
            } else {
                $ObjectTypeIcon = "❔"
            }
            #endregion

            #region Classification icon
            if ($AffectedPrivileged.AdminTierLevelName -contains 'ControlPlane') {
                $AdminTierLevelIcon = "🔐"
            } elseif ($AffectedPrivileged.AdminTierLevelName -contains 'ManagementPlane') {
                $AdminTierLevelIcon = "☁️"
            } elseif ($AffectedPrivileged.ObjectType -contains 'WorkloadPlane') {
                $AdminTierLevelIcon = "⚙️"
            } else {
                $AdminTierLevelIcon = "❔"
            }
            #endregion

            #region RoleAssignmentUrl
            if ($AffectedPrivileged.AdminTierLevelName -contains 'ControlPlane') {
                $AdminTierLevelIcon = "🔐"
            } elseif ($AffectedPrivileged.AdminTierLevelName -contains 'ManagementPlane') {
                $AdminTierLevelIcon = "☁️"
            } elseif ($AffectedPrivileged.ObjectType -contains 'WorkloadPlane') {
                $AdminTierLevelIcon = "⚙️"
            } else {
                $AdminTierLevelIcon = "❔"
            }
            #endregion


            #region RoleScope Url
            if ($AffectedPrivileged.RoleSystem -eq "IdentityGovernance" -and $AffectedPrivileged.RoleAssignmentScopeId -like "/AccessPackageCatalog/*") {
                $CatalogId = $AffectedPrivileged.RoleAssignmentScopeId -replace "/AccessPackageCatalog/", ""
                $RoleScopeName = $AffectedPrivileged.RoleAssignmentScopeName
                $RoleScopePortalUrl = "https://entra.microsoft.com/#view/Microsoft_Azure_ELMAdmin/CatalogMenuBlade/~/managers/catalogId/$($CatalogId)"
            } elseif ($AffectedPrivileged.RoleSystem -eq "Azure" -and $AffectedPrivileged.RoleAssignmentScopeId -like "/providers/microsoft.management/managementgroups/*") {
                $RoleScopeName = $AffectedPrivileged.RoleAssignmentScopeId.Replace("/providers/microsoft.management/managementgroups/","")
                $RoleScopePortalUrl = "https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/overview/provider/azurerbac/resourceDisplayName/lab/resourceExternalId/%2Fproviders%2FMicrosoft.Management%2FmanagementGroups%2F$($RoleScopeName)/tenantName//resourceType/managementgroup"
            } elseif ($AffectedPrivileged.RoleSystem -eq "EntraID" -and $AffectedPrivileged.RoleAssignmentScopeId -like "/administrativeUnits/*") {
                $RoleScopeName = $AffectedPrivileged.RoleAssignmentScopeId.Replace("/administrativeUnits/","")
                $RoleScopePortalUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AdminUnitDetailsMenuBlade/~/RolesAndAdministrators/adminUnitId/$($RoleScopeName)/adminUnitName/($RoleScopeName)"
            } elseif ($AffectedPrivileged.RoleSystem -eq "EntraID" -and $AffectedPrivileged.RoleAssignmentScopeId -eq "/") {
                $RoleScopeName = "Directory"
                $RoleScopePortalUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AllRolesBlade"
            } elseif ($AffectedPrivileged.RoleSystem -eq "ResourceApps") {

            }
            else {
                if($null -ne $AffectedPrivileged.RoleAssignmentScopeId) {
                    $RoleScopeName = $AffectedPrivileged.RoleAssignmentScopeId
                    $RoleScopePortalUrl = $null
                } else {
                    $RoleScopeName = $AffectedPrivileged.RoleAssignmentScopeName
                    $RoleScopePortalUrl = $null
                }
            }
            #endregion

            if($DescriptionIncluded -eq $true) {
                $ImpactedPrivilegesList += "| $($ObjectTypeIcon) [$($AffectedPrivileged.ObjectDisplayName)]($($ObjectPortalUrl)) | $($AdminTierLevelIcon) $($AffectedPrivileged.RoleDefinitionName) on [$($RoleScopeName)]($($RoleScopePortalUrl)) | $($AffectedPrivileged.Description) | `n"
            } else {
                $ImpactedPrivilegesList += "| $($ObjectTypeIcon) [$($AffectedPrivileged.ObjectDisplayName)]($($ObjectPortalUrl)) | $($AdminTierLevelIcon) $($AffectedPrivileged.RoleDefinitionName) on [$($RoleScopeName)]($($RoleScopePortalUrl)) | `n"
            }
        }
    }

$resultMarkdown = $ResultDescription + $ImpactedPrivilegesList

    Add-MtTestResultDetail -Description $testDescription -Result $resultMarkdown
    #endregion

    return $testResult
}
