function Test-MtCaEmergencyAccessExistsCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaEmergencyAccessExistsCompliance
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
    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $EmergencyAccessAccounts = Get-MtMaesterConfigGlobalSetting -SettingName 'EmergencyAccessAccounts'

    try {
        # Only check policies that are not related to authentication context (the state of policy does not have to be enabled)
        $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { -not $_.conditions.applications.includeAuthenticationContextClassReferences }

        # Remove policies that are scoped to service principals or agent identities
        $policies = $policies | Where-Object {
            -not $_.conditions.clientApplications.includeServicePrincipals -and
            -not $_.conditions.clientApplications.includeAgentIdServicePrincipals
        }

        $result = $false
        $PolicyCount = $policies | Measure-Object | Select-Object -ExpandProperty Count
        if (-not $EmergencyAccessAccounts -or $EmergencyAccessAccounts.Count -eq 0) {
            Write-Verbose "No emergency access accounts or groups defined in the Maester config. Use the default logic to detect emergency access accounts or groups."
            $ExcludedUserObjectGUID = $policies.conditions.users.excludeUsers | Group-Object -NoElement | Sort-Object -Property Count -Descending | Select-Object -First 1 -ExpandProperty Name
            $ExcludedUsers = $policies.conditions.users.excludeUsers | Group-Object -NoElement | Sort-Object -Property Count -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Count
            $ExcludedGroupObjectGUID = $policies.conditions.users.excludeGroups | Group-Object -NoElement | Sort-Object -Property Count -Descending | Select-Object -First 1 -ExpandProperty Name
            $ExcludedGroups = $policies.conditions.users.excludeGroups | Group-Object -NoElement | Sort-Object -Property Count -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Count

            # If the number of enabled policies is not the same as the number of excluded users or groups, there is no emergency access
            if ($PolicyCount -eq $ExcludedUsers -or $PolicyCount -eq $ExcludedGroups) {
                $result = $true
            } else {
                # If the number of excluded users is higher than the number of excluded groups, check the user object GUID
                $CheckId = $ExcludedGroupObjectGUID
                $EmergencyAccessUUIDType = 'group'
                if ($ExcludedUsers -gt $ExcludedGroups) {
                    $EmergencyAccessUUIDType = 'user'
                    $CheckId = $ExcludedUserObjectGUID
                }

                # Get displayName of the emergency access account or group
                if ($CheckId) {
                    if ($EmergencyAccessUUIDType -eq 'user') {
                        $DisplayName = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users/$CheckId' -Select displayName | Select-Object -ExpandProperty displayName
                    } else {
                        $DisplayName = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/groups/$CheckId' -Select displayName | Select-Object -ExpandProperty displayName
                    }

                    Write-Verbose "Emergency access account or group: $CheckId"
                    $testResult = "Automatically detected emergency access`n`n* $($EmergencyAccessUUIDType): $DisplayName ($CheckId)`n`n"
                }

                $policiesWithoutEmergency = $policies | Where-Object { $CheckId -notin $_.conditions.users.excludeUsers -and $CheckId -notin $_.conditions.users.excludeGroups }
                $policiesWithoutEmergency | Select-Object -ExpandProperty displayName | Sort-Object | ForEach-Object {
                    Write-Verbose "Conditional Access policy $_ does not exclude emergency access $EmergencyAccessUUIDType"
                }
            }

            return $result

        } else {
            # Resolve emergency access accounts/groups to object IDs and get display names
            $ResolvedEmergencyAccessAccounts = @()
            foreach ($account in $EmergencyAccessAccounts) {
                # Use either Id or UserPrincipalName to identify the account / group and UserPrincipalName as fallback
                $identifier = if ($account.Id) { $account.Id } else { $account.UserPrincipalName }
                # Determine the type (user or group) while defaulting to 'user'
                $type = if ($account.Type) { $account.Type.ToLower() } else { 'user' }

                if ($identifier -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                    # It's an object ID
                    try {
                        $endpoint = if ($type -eq 'group') { "groups/$identifier" } else { "users/$identifier" }
                        $object = Invoke-MtGraphRequest -RelativeUri $endpoint -Select id, displayName -ErrorAction Stop
                        if ($object) {
                            Write-Verbose "Emergency access $type`: $($object.displayName) ($identifier)"
                            $ResolvedEmergencyAccessAccounts += @{ObjectId = $object.id; displayName = $object.displayName; type = $type }
                        } else {
                            Write-Warning "Could not resolve emergency access $type ID: $identifier"
                        }
                    } catch {
                        Write-Warning "Could not resolve emergency access $type ID: $identifier. Error: $_"
                    }
                } elseif ($identifier -match '^[^@]+@[^@]+\.[^@]+$') {
                    # It's a UPN - could be user or group
                    try {
                        $endpoint = if ($type -eq 'group') { "groups" } else { "users/$identifier" }
                        if ($type -eq 'group') {
                            # For groups, we need to filter by mail or mailNickname
                            $object = Invoke-MtGraphRequest -RelativeUri $endpoint -Filter "mail eq '$identifier' or mailNickname eq '$identifier'" -ErrorAction Stop | Select-Object -First 1
                        } else {
                            $object = Invoke-MtGraphRequest -RelativeUri $endpoint -Select id, displayName -ErrorAction Stop
                        }
                        if ($object) {
                            Write-Verbose "Emergency access $type`: $($object.displayName) ($($object.id))"
                            $ResolvedEmergencyAccessAccounts += @{ObjectId = $object.id; displayName = $object.displayName; type = $type }
                        } else {
                            Write-Warning "Could not resolve emergency access $type`: $identifier"
                        }
                    } catch {
                        Write-Warning "Could not resolve emergency access $type`: $identifier. Error: $_"
                    }
                } else {
                    Write-Warning "Invalid identifier format for emergency access account: $identifier"
                }
            }
            Write-Verbose "Emergency access accounts or groups defined in the Maester config: $($EmergencyAccessAccounts.Count) entries"
            $UniqueResolvedEmergencyAccessAccounts = @()
            $ResolvedEmergencyAccessAccountKeys = @{}
            foreach ($account in $ResolvedEmergencyAccessAccounts) {
                $accountKey = "$($account.type):$($account.ObjectId)"
                if (-not $ResolvedEmergencyAccessAccountKeys.ContainsKey($accountKey)) {
                    $ResolvedEmergencyAccessAccountKeys[$accountKey] = $true
                    $UniqueResolvedEmergencyAccessAccounts += $account
                }
            }
            $ResolvedEmergencyAccessAccounts = $UniqueResolvedEmergencyAccessAccounts
            $ResolvedEmergencyAccessUsers = $ResolvedEmergencyAccessAccounts | Where-Object { $_.type -eq 'user' }
            $ResolvedEmergencyAccessGroups = $ResolvedEmergencyAccessAccounts | Where-Object { $_.type -eq 'group' }
            $EmergencyAccessAccountsUserCount = @($ResolvedEmergencyAccessUsers).Count
            $EmergencyAccessAccountsGroupCount = @($ResolvedEmergencyAccessGroups).Count

            if ($EmergencyAccessAccountsUserCount -eq 0 -and $EmergencyAccessAccountsGroupCount -eq 0) {
                return $false
            }

            # Find policies that are missing ANY of the configured emergency access accounts or groups
            $policiesWithoutEmergency = $policies | Where-Object {
                $CurrentPolicy = $_
                $missingEmergency = $false

                # Check if all configured emergency users are excluded
                if ($EmergencyAccessAccountsUserCount -gt 0) {
                    $ExcludedKnownUsers = @($CurrentPolicy.conditions.users.excludeUsers | Where-Object { $_ -in $ResolvedEmergencyAccessUsers.ObjectId }).Count
                    if ($ExcludedKnownUsers -lt $EmergencyAccessAccountsUserCount) {
                        $missingEmergency = $true
                    }
                }

                # Check if all configured emergency groups are excluded
                if ($EmergencyAccessAccountsGroupCount -gt 0) {
                    $ExcludedKnownGroups = @($CurrentPolicy.conditions.users.excludeGroups | Where-Object { $_ -in $ResolvedEmergencyAccessGroups.ObjectId }).Count
                    if ($ExcludedKnownGroups -lt $EmergencyAccessAccountsGroupCount) {
                        $missingEmergency = $true
                    }
                }

                $missingEmergency
            }
            if ($policiesWithoutEmergency.Count -eq 0) {
                $result = $true
                $testResult = "All conditional access policies exclude the configured emergency access accounts or groups:`n`n"
                $ResolvedEmergencyAccessAccounts | ForEach-Object {
                    $typeLabel = if ($_.type -eq 'group') { 'Group' } else { 'User' }
                    if ($_.displayName) {
                        $testResult += "* $typeLabel`: $($_.displayName) ($($_.ObjectId))`n"
                    } else {
                        $testResult += "* $typeLabel`: $($_.ObjectId)`n"
                    }
                }
                return $result
            } else {
                $testResult = "Configured emergency access accounts or groups:`n`n"
                $ResolvedEmergencyAccessAccounts | ForEach-Object {
                    $typeLabel = if ($_.type -eq 'group') { 'Group' } else { 'User' }
                    if ($_.displayName) {
                        $testResult += "* $typeLabel`: $($_.displayName) ($($_.ObjectId))`n"
                    } else {
                        $testResult += "* $typeLabel`: $($_.ObjectId)`n"
                    }
                }
                return $result
            }
        }
    } catch {
        return $null
    }

}
