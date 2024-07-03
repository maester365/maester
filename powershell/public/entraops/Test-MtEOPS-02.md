Avoid the direct assignment of privileged objects without restricted management to Azure RBAC with High Privileged Roles on Tenant Root or Management Group.

#### Test script
```
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

($QueryResult | Measure-Object | Select-Object -ExpandProperty Count) -eq "0"

```

<!--- Results --->
%TestResult%
