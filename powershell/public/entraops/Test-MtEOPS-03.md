Avoid assignment of ownership to privileged objects.

#### Test script
```
$GroupWithOwners = $EntraOpsPrivilegedEamData `
  | Where-Object {$_.ObjectType -eq "group"} `
  | Where-Object {$_.Owners -ne $null}
$GroupOwners = $GroupWithOwners | ForEach-Object {
    $Owners = $_.Owners | ForEach-Object {
        Get-EntraOpsPrivilegedEntraObject -AadObjectId $_
    }
    [PSCustomObject]@{
        "ObjectId" = $_.ObjectId
        "Owners" = $Owners
    }
}
$QueryResult = foreach ($GroupWithOwner in $GroupWithOwners) {
      $Description = ((($GroupOwners | Where-Object {$_.ObjectId -eq $GroupWithOwner.ObjectId}) | Select-Object -ExpandProperty Owners) | Select-Object ObjectSignInName).ObjectSignInName
      [PSCustomObject]@{
          "ObjectDisplayName"        = $GroupWithOwner.ObjectDisplayName
          "ObjectType"               = $GroupWithOwner.ObjectType
          "ObjectId"                 = $GroupWithOwner.ObjectId
          "RoleDefinitionName"       = "Owners"
          "RoleAssignmentScopeName"  = "group"
          "RoleSystem"               = "Resource"
          "AdminTierLevelName"       = ($GroupWithOwner.classification | Sort-Object AdminTierLevel)[0].AdminTierLevelName
          "Description"              = $Description
      }
}

($QueryResult | Measure-Object | Select-Object -ExpandProperty Count) -eq "0"

```

<!--- Results --->
%TestResult%
