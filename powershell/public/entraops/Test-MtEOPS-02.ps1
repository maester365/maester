<#
.SYNOPSIS
    Executes EntraOps Query Permanent and Direct Role Assignments in Azure RBAC on Management Groups without Restricted Management

.DESCRIPTION

    Avoid the direct assignment of privileged objects without restricted management to Azure RBAC with High Privileged Roles on Tenant Root or Management Group.

    Queries EntraOps classification data
    and returns and validate if result is $true.

.EXAMPLE
    Test-MtEOPS-02

    Returns the result of Permanent and Direct Role Assignments in Azure RBAC on Management Groups without Restricted Management
#>

Function Test-MtEOPS-02 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    #region Query from EntraOps YAML file
    $AzPrivilegedRolesQuery = 'AuthorizationResources
| where type =~ "microsoft.authorization/roleassignments"
| extend ObjectType = tostring(properties["principalType"])
| extend ObjectId = tostring(properties["principalId"])
| extend roleDefinitionId = tolower(tostring(properties["roleDefinitionId"]))
| extend Scope = tolower(tostring(properties["scope"]))
| mv-expand parse_json(Scope)
| join kind=inner ( AuthorizationResources
| where type =~ "microsoft.authorization/roledefinitions"
| extend roleDefinitionId = tolower(id)
| extend Scope = tolower(properties.assignableScopes)
| extend RoleName = (properties.roleName)
| where RoleName in ("Owner",
      "Access Review Operator Service Role",
      "Contributor",
      "Role Based Access Control Administrator",
      "User Access Administrator")
) on roleDefinitionId
| where Scope in (
    "/"
    )
    or Scope startswith (
    "/providers/microsoft.management/managementgroups/"
    )
| project ObjectId, ObjectType, RoleName, Scope'
$AzPrivilegedRoles = Invoke-EntraOpsAzGraphQuery -KqlQuery $AzPrivilegedRolesQuery
$AzPrivilegedPrincipals = $AzPrivilegedRoles | Select-Object -unique ObjectId
$QueryResult = foreach ($AzPrivilegedPrincipal in $AzPrivilegedPrincipals) {
        $UnprotectedAzureAdmin = Get-EntraOpsPrivilegedEntraObject -AadObjectId $AzPrivilegedPrincipal.ObjectId `
                | Where-Object {$_.RestrictedManagementByRMAU -ne $True -and $_.ObjectType -ne "serviceprincipal2" `
                        -and $_.RestrictedManagementByAadRole -ne $True `
                        -and $_.RestrictedManagementByRAG -ne $True
                        }
        if($UnprotectedAzureAdmin) {
            $RoleAssignments = $AzPrivilegedRoles | Where-Object {$_.ObjectId -eq $AzPrivilegedPrincipal.ObjectId -and $_.ObjectSignInName -ne "01fc33a7-78ba-4d2f-a4b7-768e336e890e" } | Select-Object RoleName, Scope
            $PrivilegedPrincipalAssignments = $RoleAssignments | ForEach-Object {
                [PSCustomObject]@{
                    "ObjectDisplayName"        = $UnprotectedAzureAdmin.ObjectDisplayName
                    "ObjectType"               = $UnprotectedAzureAdmin.ObjectType
                    "ObjectId"                 = $UnprotectedAzureAdmin.ObjectId
                    "SignInName"               = $UnprotectedAzureAdmin.ObjectSignInName
                    "RoleAssignmentId"         = $_.id
                    "RoleDefinitionName"       =  $_.RoleName
                    "RoleAssignmentScopeId"    = $_.Scope
                    "RoleAssignmentScopeName"  = ""
                    "RoleSystem"               = "Azure"
                    "AdminTierLevelName"       = $UnprotectedAzureAdmin.AdminTierLevelName
                    "Description"              = $null
                }
            }
            # Filter out the service principal for MS-PIM
            $PrivilegedPrincipalAssignments | where-object {$_.SignInName -ne "01fc33a7-78ba-4d2f-a4b7-768e336e890e"}
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
