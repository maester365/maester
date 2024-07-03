Avoid the direct assignment of privileged objects without restricted management to Azure RBAC with High Privileged Roles on Tenant Root or Management Group.

#### Test script
```
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

($QueryResult | Measure-Object | Select-Object -ExpandProperty Count) -eq "0"

```

<!--- Results --->
%TestResult%
