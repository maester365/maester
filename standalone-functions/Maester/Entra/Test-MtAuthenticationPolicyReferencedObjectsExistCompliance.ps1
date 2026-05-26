function Test-MtAuthenticationPolicyReferencedObjectsExistCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAuthenticationPolicyReferencedObjectsExistCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

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
            return $true
        }

        # Collections to store results
        $nonExistentGroups = [System.Collections.Generic.List[object]]::new()
        $authMethodIssues = [System.Collections.Generic.List[string]]::new()

        # Check each referenced group
        Write-Verbose "Checking $($uniqueGroupIds.Count) unique groups referenced in authentication method policies"

        foreach ($groupId in $uniqueGroupIds) {
            try {
                $group = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/groups/$groupId' -ErrorAction Stop
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

            return $false
        }

        Write-Verbose "All referenced groups exist"
        return $true

    } catch {
        return $false
    }

}
