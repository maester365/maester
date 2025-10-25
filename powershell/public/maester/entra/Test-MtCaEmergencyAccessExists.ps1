<#
 .Synopsis
  Checks if the tenant has at least one emergency/break glass account or account group excluded from all conditional access policies

 .Description
  It is recommended to have at least one emergency/break glass account or account group excluded from all conditional access policies.
  This allows for emergency access to the tenant in case of a misconfiguration or other issues.

  Learn more:
  https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access

 .Example
  Test-MtCaEmergencyAccessExists

.LINK
    https://maester.dev/docs/commands/Test-MtCaEmergencyAccessExists
#>
function Test-MtCaEmergencyAccessExists {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Exists is not a plural.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    $EmergencyAccessAccounts = Get-MtMaesterConfigGlobalSetting -SettingName 'EmergencyAccessAccounts'

    try {
        # Only check policies that are not related to authentication context (the state of policy does not have to be enabled)
        $policies = Get-MtConditionalAccessPolicy | Where-Object { -not $_.conditions.applications.includeAuthenticationContextClassReferences }

        # Remove policies that are scoped to service principals
        $policies = $policies | Where-Object { -not $_.conditions.clientApplications.includeServicePrincipals }

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
                        $DisplayName = Invoke-MtGraphRequest -RelativeUri "users/$CheckId" -Select displayName | Select-Object -ExpandProperty displayName
                    } else {
                        $DisplayName = Invoke-MtGraphRequest -RelativeUri "groups/$CheckId" -Select displayName | Select-Object -ExpandProperty displayName
                    }

                    Write-Verbose "Emergency access account or group: $CheckId"
                    $testResult = "Automatically detected emergency access`n`n* $($EmergencyAccessUUIDType): $DisplayName ($CheckId)`n`n"
                }

                $policiesWithoutEmergency = $policies | Where-Object { $CheckId -notin $_.conditions.users.excludeUsers -and $CheckId -notin $_.conditions.users.excludeGroups }
                $policiesWithoutEmergency | Select-Object -ExpandProperty displayName | Sort-Object | ForEach-Object {
                    Write-Verbose "Conditional Access policy $_ does not exclude emergency access $EmergencyAccessUUIDType"
                }
            }

            $testResult += "These conditional access policies don't have the emergency access $EmergencyAccessUUIDType excluded:`n`n%TestResult%"
            Add-MtTestResultDetail -GraphObjects $policiesWithoutEmergency -GraphObjectType ConditionalAccess -Result $testResult
            return $result

        } else {
            # Translate any UPNs to object IDs and get display names for UUIDs
            $ResolvedEmergencyAccessAccounts = @()
            foreach ($account in $EmergencyAccessAccounts) {
                if ($account -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                    # It's already an object ID
                    # Get the display name to show in the test result
                    $DisplayName = Invoke-MtGraphRequest -RelativeUri "directoryObjects/$account" -Select displayName | Select-Object -ExpandProperty displayName
                    if ($DisplayName) {
                        Write-Verbose "Emergency access account or group: $DisplayName ($account)"
                    } else {
                        Write-Verbose "Emergency access account or group: $account"
                    }
                    $ResolvedEmergencyAccessAccounts += @{ObjectId = $account; displayName = $DisplayName }
                } elseif ($account -match '^[^@]+@[^@]+\.[^@]+$') {
                    # It's a UPN, resolve it to an object ID
                    try {
                        $user = Invoke-MtGraphRequest -RelativeUri "users/$account" -Select id, displayName -ErrorAction Stop
                        if ($user) {
                            $ResolvedEmergencyAccessAccounts += @{ObjectId = $user.id; displayName = $user.displayName }
                        } else {
                            Write-Warning "Could not resolve emergency access account UPN: $account"
                        }
                    } catch {
                        Write-Warning "Could not resolve emergency access account UPN: $account. Error: $_"
                    }
                } else {
                    # Assume it's a display name, try to resolve it to an object ID
                    try {
                        $group = Invoke-MtGraphRequest -RelativeUri "groups" -Filter "displayName eq '$account'" -ErrorAction Stop
                        if ($group) {
                            $ResolvedEmergencyAccessAccounts += @{ObjectId = $group.id; displayName = $group.displayName }
                        } else {
                            Write-Warning "Could not resolve emergency access group display name: $account"
                        }
                    } catch {
                        Write-Warning "Could not resolve emergency access group display name: $account. Error: $_"
                    }
                }
            }
            Write-Verbose "Emergency access accounts or groups defined in the Maester config: $($EmergencyAccessAccounts -join ', ')"
            $policiesWithoutEmergency = $policies | Where-Object {
                ($_.conditions.users.excludeUsers | Where-Object { $ResolvedEmergencyAccessAccounts.ObjectId -contains $_ }).Count -eq 0 -and
                ($_.conditions.users.excludeGroups | Where-Object { $ResolvedEmergencyAccessAccounts.ObjectId -contains $_ }).Count -eq 0
            }
            if ($policiesWithoutEmergency.Count -eq 0) {
                $result = $true
                $testResult = "All conditional access policies exclude the configured emergency access accounts or groups:`n`n"
                $ResolvedEmergencyAccessAccounts | ForEach-Object {
                    if ($_.displayName) {
                        $testResult += "* $($_.displayName) ($($_.ObjectId))`n"
                    } else {
                        $testResult += "* $($_.ObjectId)`n"
                    }
                }
            } else {
                $testResult = "Configured emergency access accounts or groups:`n`n"
                $ResolvedEmergencyAccessAccounts | ForEach-Object {
                    if ($_.displayName) {
                        $testResult += "* $($_.displayName) ($($_.ObjectId))`n"
                    } else {
                        $testResult += "* $($_.ObjectId)`n"
                    }
                }
                $testResult += "`n`nThese conditional access policies don't have the configured emergency access accounts or groups excluded:`n`n%TestResult%"
                Add-MtTestResultDetail -GraphObjects $policiesWithoutEmergency -GraphObjectType ConditionalAccess -Result $testResult
                return $result
            }
        }
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
