<#
.SYNOPSIS
    Executes EntraOps Query Identity Governance role assignment on catalog with privileged objects outside from classification of the administrator

.DESCRIPTION

    Avoid the assignment of privileged objects to administrators outside the classification of the administrator.

    Queries EntraOps classification data
    and returns and validate if result is $true.

.EXAMPLE
    Test-MtEOPS-01

    Returns the result of Identity Governance role assignment on catalog with privileged objects outside from classification of the administrator
#>

Function Test-MtEOPS-01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    #region Query from EntraOps YAML file
    $ElmCatalogAssignments = $EntraOpsPrivilegedEamData | where-object {$_.RoleSystem -eq "IdentityGovernance"} `
                                | Select-Object -ExpandProperty RoleAssignments `
                                | Where-Object {$_.Classification.TaggedBy -contains "AssignedCatalogObjects"}
    foreach($ElmCatalogAssignment in $ElmCatalogAssignments){
        $PrincipalClassification = $EntraOpsPrivilegedEamData | Where-Object {$_.ObjectId -eq $ElmCatalogAssignment.ObjectId} `
                                    | Where-Object {$_.RoleSystem -ne "IdentityGovernance"} `
                                    | Select-Object -ExpandProperty RoleAssignments `
                                    | Select-Object -ExpandProperty Classification `
                                    | Select-Object -Unique AdminTierLevelName, Service `
                                    | Sort-Object -Property AdminTierLevelName, Service
        if ($null -eq $PrincipalClassification) {
            Write-Warning "No Principal Classification found for $($ElmCatalogAssignment.ObjectId)"
            $PrincipalClassification = @(
                [PSCustomObject]@{
                    AdminTierLevelName = "User Access"
                    Service = "No Classification"
                }
            )
        }
        $ElmCatalogClassification = $ElmCatalogAssignment | Select-Object -ExpandProperty Classification `
                                    | Where-Object {$_.TaggedBy -eq "AssignedCatalogObjects"} `
                                    | Select-Object -Unique AdminTierLevelName, Service `
                                    | Sort-Object -Property AdminTierLevelName, Service

        $Differences = Compare-Object -ReferenceObject ($ElmCatalogClassification) `
        -DifferenceObject ($PrincipalClassification) -Property AdminTierLevelName, Service `
        | Where-Object {$_.SideIndicator -eq "<="} | Select-Object * -ExcludeProperty SideIndicator
        if ($null -ne $Differences) {
            try {
                $Principal = Get-EntraOpsEntraObject -AadObjectId $ElmCatalogAssignment.ObjectId
            }
            catch {
                $Principal = [PSCustomObject]@{
                    ObjectDisplayName = "Unknown"
                    ObjectType = "Unknown"
                }
            }
        }
        if ($Differences) {
            $QueryResult = $Differences | ForEach-Object {
                    [PSCustomObject]@{
                        "ObjectDisplayName"        = $Principal.ObjectDisplayName
                        "ObjectType"               = $Principal.ObjectType
                        "ObjectId"                 = $Principal.ObjectId
                        "SignInName"               = $Principal.ObjectSignInName
                        "RoleSystem"               = "IdentityGovernance"
                        "RoleAssignmentId"         = $ElmCatalogAssignment.RoleAssignmentId
                        "RoleDefinitionName"       = $ElmCatalogAssignment.RoleDefinitionName
                        "RoleAssignmentScopeId"    = $ElmCatalogAssignment.RoleAssignmentScopeId
                        "RoleAssignmentScopeName"  = $ElmCatalogAssignment.RoleAssignmentScopeName
                        "AdminTierLevelName"       = $_.AdminTierLevelName
                        "Description"              = "$($_.Service) is not included in users' permissions."
                    }
            }
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
