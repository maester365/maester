function Test-MtCaReferencedObjectsExist {
<#
    .Synopsis
    Checks if any conditional access policies reference non-existent users, groups, or roles.

    .Description
    This test checks if all users, groups, and roles referenced in conditional access policies still exist in the tenant.
    Non-existent or deleted objects in conditional access policies can lead to unexpected behavior and security gaps.
    When a user, group, or role is deleted but still referenced in a policy, it may cause the policy to not apply as expected.

    The test examines:
    - Include/exclude users in conditional access policies
    - Include/exclude groups in conditional access policies
    - Include/exclude roles in conditional access policies (role definition IDs)

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-users-groups

    .Example
    Test-MtCaReferencedObjectsExist

    .LINK
    https://maester.dev/docs/commands/Test-MtCaReferencedObjectsExist
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    Write-Verbose 'Running Test-MtCaReferencedObjectsExist'

    try {
        $testDescription = 'Invalid or deleted users, groups, or roles are referenced in Conditional Access policies.'

        # Get all policies (the state of policy does not have to be enabled)
        $policies = Get-MtConditionalAccessPolicy

        # Collect all referenced objects
        $allUsers = $policies.conditions.users.includeUsers + $policies.conditions.users.excludeUsers | Where-Object { $_ -ne 'All' -and $_ -ne 'GuestsOrExternalUsers' -and $_ -ne $null -and $_ -ne '' } | Select-Object -Unique
        $allGroups = $policies.conditions.users.includeGroups + $policies.conditions.users.excludeGroups | Where-Object { $_ -ne $null -and $_ -ne '' } | Select-Object -Unique
        $allRoles = $policies.conditions.users.includeRoles + $policies.conditions.users.excludeRoles | Where-Object { $_ -ne $null -and $_ -ne '' } | Select-Object -Unique

        # Collections to store non-existent objects
        $nonExistentUsers = [System.Collections.Generic.List[object]]::new()
        $nonExistentGroups = [System.Collections.Generic.List[object]]::new()
        $nonExistentRoles = [System.Collections.Generic.List[object]]::new()

        # Check users
        if ($allUsers) {
            Write-Verbose "Checking $($allUsers.Count) users"
            $allUsers | ForEach-Object {
                try {
                    $GraphErrorResult = $null
                    $user = $_
                    Invoke-MtGraphRequest -RelativeUri "users/$user" -ApiVersion beta -ErrorVariable GraphErrorResult -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    if ($GraphErrorResult.Message -match '404 Not Found') {
                        $nonExistentUsers.Add($user) | Out-Null
                    }
                }
            }
        }

        # Check groups
        if ($allGroups) {
            Write-Verbose "Checking $($allGroups.Count) groups"
            $allGroups | ForEach-Object {
                try {
                    $GraphErrorResult = $null
                    $group = $_
                    Invoke-MtGraphRequest -RelativeUri "groups/$group" -ApiVersion beta -ErrorVariable GraphErrorResult -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    if ($GraphErrorResult.Message -match '404 Not Found') {
                        $nonExistentGroups.Add($group) | Out-Null
                    }
                }
            }
        }

        # Check roles
        if ($allRoles) {
            Write-Verbose "Checking $($allRoles.Count) roles"
            $allRoles | ForEach-Object {
                try {
                    $GraphErrorResult = $null
                    $role = $_
                    Write-Verbose "Checking role: $role"
                    # Check roleManagement/directory/roleDefinitions as conditional access policies reference role definition IDs
                    Invoke-MtGraphRequest -RelativeUri "roleManagement/directory/roleDefinitions/$role" -ApiVersion beta -ErrorVariable GraphErrorResult -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    Write-Verbose "Error checking role $role : $($GraphErrorResult.Message)"
                    if ($GraphErrorResult.Message -match '404 Not Found') {
                        $nonExistentRoles.Add($role) | Out-Null
                    }
                }
            }
        }

        # Check if any non-existent objects were found
        $totalNonExistentObjects = ($nonExistentUsers | Measure-Object).Count + ($nonExistentGroups | Measure-Object).Count + ($nonExistentRoles | Measure-Object).Count
        $result = $totalNonExistentObjects -eq 0

        if ($result) {
            $resultDescription = 'Well done! All users, groups, and roles referenced in Conditional Access policies exist in the tenant.'
            $resultMarkdown = $resultDescription
        } else {
            $resultDescription = 'These Conditional Access policies reference non-existent users, groups, or roles:'
            $impactedCaObjects = "`n`n#### Impacted Conditional Access policies`n`n"
            $impactedCaObjects += "| Conditional Access policy | Non-existent object | Object type | Condition | `n"
            $impactedCaObjects += "| --- | --- | --- | --- |`n"

            # Process non-existent users
            $nonExistentUsers | Sort-Object | ForEach-Object {
                $invalidUserId = $_
                $impactedPolicies = $policies | Where-Object { $_.conditions.users.includeUsers -contains $invalidUserId -or $_.conditions.users.excludeUsers -contains $invalidUserId }
                foreach ($impactedPolicy in $impactedPolicies) {
                    if ($impactedPolicy.conditions.users.includeUsers -contains $invalidUserId) {
                        $condition = 'include'
                    } elseif ($impactedPolicy.conditions.users.excludeUsers -contains $invalidUserId) {
                        $condition = 'exclude'
                    } else {
                        $condition = 'Unknown'
                    }
                    $policy = (Get-GraphObjectMarkdown -GraphObjects $impactedPolicy -GraphObjectType ConditionalAccess -AsPlainTextLink)
                    $impactedCaObjects += "| $policy | $invalidUserId | User | $condition | `n"
                }
            }

            # Process non-existent groups
            $nonExistentGroups | Sort-Object | ForEach-Object {
                $invalidGroupId = $_
                $impactedPolicies = $policies | Where-Object { $_.conditions.users.includeGroups -contains $invalidGroupId -or $_.conditions.users.excludeGroups -contains $invalidGroupId }
                foreach ($impactedPolicy in $impactedPolicies) {
                    if ($impactedPolicy.conditions.users.includeGroups -contains $invalidGroupId) {
                        $condition = 'include'
                    } elseif ($impactedPolicy.conditions.users.excludeGroups -contains $invalidGroupId) {
                        $condition = 'exclude'
                    } else {
                        $condition = 'Unknown'
                    }
                    $policy = (Get-GraphObjectMarkdown -GraphObjects $impactedPolicy -GraphObjectType ConditionalAccess -AsPlainTextLink)
                    $impactedCaObjects += "| $policy | $invalidGroupId | Group | $condition | `n"
                }
            }

            # Process non-existent roles
            $nonExistentRoles | Sort-Object | ForEach-Object {
                $invalidRoleId = $_
                $impactedPolicies = $policies | Where-Object { $_.conditions.users.includeRoles -contains $invalidRoleId -or $_.conditions.users.excludeRoles -contains $invalidRoleId }
                foreach ($impactedPolicy in $impactedPolicies) {
                    if ($impactedPolicy.conditions.users.includeRoles -contains $invalidRoleId) {
                        $condition = 'include'
                    } elseif ($impactedPolicy.conditions.users.excludeRoles -contains $invalidRoleId) {
                        $condition = 'exclude'
                    } else {
                        $condition = 'Unknown'
                    }
                    $policy = (Get-GraphObjectMarkdown -GraphObjects $impactedPolicy -GraphObjectType ConditionalAccess -AsPlainTextLink)
                    $impactedCaObjects += "| $policy | $invalidRoleId | Role | $condition | `n"
                }
            }

            $impactedCaObjects += "`n`nNote: Names are not available for deleted objects. If the object was deleted recently, it may be available in the recycle bin (for groups and users) or may need to be re-created (for roles).`n`n"
            $resultMarkdown = $resultDescription + $impactedCaObjects
        }

        Add-MtTestResultDetail -Description $testDescription -Result $resultMarkdown
        return $result

    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
