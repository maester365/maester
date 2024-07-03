Avoid the assignment of privileged objects to administrators outside the classification of the administrator.

#### Test script
```
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

($QueryResult | Measure-Object | Select-Object -ExpandProperty Count) -eq "0"

```

<!--- Results --->
%TestResult%
