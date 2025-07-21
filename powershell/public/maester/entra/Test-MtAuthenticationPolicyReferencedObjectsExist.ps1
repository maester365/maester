function Test-MtAuthenticationPolicyReferencedObjectsExist {
<#
    .Synopsis
    Checks if authentication method policies reference valid groups that exist in the tenant.

    .Description
    This test checks if all groups referenced in authentication method policies still exist in the tenant.
    Authentication method policies can reference groups in their includeTargets configuration. If a group
    is deleted but still referenced in an authentication method policy, it may cause the policy to not
    apply as expected or result in unexpected behavior.

    The test examines includeTargets for all authentication method configurations and validates that
    any group references are valid and the groups still exist in the tenant.

    Learn more:
    https://learn.microsoft.com/entra/identity/authentication/concept-authentication-methods

    .Example
    Test-MtAuthenticationPolicyReferencedObjectsExist

    .LINK
    https://maester.dev/docs/commands/Test-MtAuthenticationPolicyReferencedObjectsExist
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose 'Running Test-MtAuthenticationPolicyReferencedObjectsExist'

    try {
        # Get all authentication method configurations
        $authMethodConfigs = Get-MtAuthenticationMethodPolicyConfig

        # Collect all referenced group IDs from includeTargets
        $allGroupIds = [System.Collections.Generic.List[string]]::new()

        foreach ($config in $authMethodConfigs) {
            if ($config.includeTargets) {
                foreach ($target in $config.includeTargets) {
                    # Only check if the target ID looks like a group ID (not "all_users" or other special values)
                    if ($target.id -and $target.id -ne 'all_users' -and $target.id -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
                        $allGroupIds.Add($target.id)
                    }
                }
            }
        }

        # Remove duplicates
        $uniqueGroupIds = $allGroupIds | Select-Object -Unique

        if (-not $uniqueGroupIds) {
            Write-Verbose "No groups found in authentication method policies."
            Add-MtTestResultDetail -Result "No groups are referenced in authentication method policies." -GraphObjectType Groups
            return $true
        }

        # Collections to store results
        $nonExistentGroups = [System.Collections.Generic.List[object]]::new()
        $authMethodIssues = [System.Collections.Generic.List[string]]::new()

        # Check each referenced group
        Write-Verbose "Checking $($uniqueGroupIds.Count) unique groups referenced in authentication method policies"

        foreach ($groupId in $uniqueGroupIds) {
            try {
                $group = Invoke-MtGraphRequest -RelativeUri "groups/$groupId" -ErrorAction Stop
                Write-Verbose "Group $groupId exists: $($group.displayName)"
            } catch {
                Write-Verbose "Group $groupId does not exist or is not accessible"
                $nonExistentGroups.Add($groupId)
            }
        }

        # If we found non-existent groups, identify which auth method policies reference them
        if ($nonExistentGroups.Count -gt 0) {
            Write-Verbose "Found $($nonExistentGroups.Count) non-existent groups"

            foreach ($invalidGroupId in $nonExistentGroups) {
                # Find which authentication method configurations reference this group
                $impactedConfigs = $authMethodConfigs | Where-Object {
                    $_.includeTargets | Where-Object { $_.id -eq $invalidGroupId }
                }

                foreach ($config in $impactedConfigs) {
                    $authMethodIssues.Add("| $($config.id) | $($config.displayName) | $($invalidGroupId) |")
                }
            }

            # Build the test result message
            $testResult = "❌ Found $($nonExistentGroups.Count) non-existent group(s) referenced in authentication method policies:`n`n"
            $testResult += "| Authentication Method | Display Name | Non-existent Group ID |`n"
            $testResult += "|---|---|---|`n"
            $testResult += ($authMethodIssues -join "`n")

            Add-MtTestResultDetail -Result $testResult -GraphObjectType Groups
            return $false
        }

        Write-Verbose "All referenced groups exist"
        Add-MtTestResultDetail -Result "✅ All groups referenced in authentication method policies exist in the tenant." -GraphObjectType Groups
        return $true

    } catch {
        Add-MtTestResultDetail -Result "Error testing authentication method policy group references: $($_.Exception.Message)" -GraphObjectType Groups
        return $false
    }
}
