<#
.SYNOPSIS
    Tests if Entra ID device join is restricted to selected users/groups or disabled.
.DESCRIPTION
    This function checks if Entra ID device join is restricted to selected users/groups or completely disabled by querying the device registration policy settings.
.OUTPUTS
    [bool] - Returns $true if device join is restricted to selected users/groups or disabled, otherwise returns $false.
.EXAMPLE
    Test-MtEntraDeviceJoinRestricted
.LINK
    https://maester.dev/docs/commands/Test-MtEntraDeviceJoinRestricted
#>
function Test-MtEntraDeviceJoinRestricted {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Add the connection check
    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose 'Test-MtEntraDeviceJoinRestricted: Checking if device join is restricted to selected users/groups or none..'

    try {
        # Get the device registration policy settings
        Write-Verbose 'Querying policies/deviceRegistrationPolicy endpoint...'
        $settings = Invoke-MtGraphRequest -RelativeUri 'policies/deviceRegistrationPolicy' -ApiVersion 'beta' -ErrorAction Stop

        # Initialize the result variable
        $deviceJoinRestricted = $false

        # Check if azureADJoin exists and get the allowedToJoin setting
        if ($null -ne $settings.azureADJoin -and $null -ne $settings.azureADJoin.allowedToJoin) {
            $allowedToJoinType = $settings.azureADJoin.allowedToJoin.'@odata.type'
            Write-Verbose "Found azureADJoin.allowedToJoin @odata.type: '$allowedToJoinType'"

            switch ($allowedToJoinType) {
                '#microsoft.graph.enumeratedDeviceRegistrationMembership' {
                    $deviceJoinRestricted = $true
                    Write-Verbose 'Device join is restricted to selected users/groups'

                    $deviceJoinValue = 'Selected users/groups can join devices.'
                    $statusValue = '✅'

                    # Get details about allowed users and groups
                    $allowedUsers = if ($settings.azureADJoin.allowedToJoin.users) { $settings.azureADJoin.allowedToJoin.users } else { @() }
                    $allowedGroups = if ($settings.azureADJoin.allowedToJoin.groups) { $settings.azureADJoin.allowedToJoin.groups } else { @() }

                    Write-Verbose "Allowed users: $($allowedUsers.Count), Allowed groups: $($allowedGroups.Count)"

                    # Build table for allowed objects with display names
                    $allowedObjects = @()

                    # Add users to the list - get display names
                    foreach ($userId in $allowedUsers) {
                        try {
                            $user = Invoke-MtGraphRequest -RelativeUri "users/$userId" -ApiVersion 'v1.0' -ErrorAction Stop
                            $displayName = if ($user.displayName) { $user.displayName } else { $user.userPrincipalName }
                            $allowedObjects += [PSCustomObject]@{
                                Type = 'User'
                                DisplayName = "[$displayName]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$userId)"
                                ID = $userId
                            }
                        } catch {
                            Write-Verbose "Could not retrieve user details for $userId`: $($_.Exception.Message)"
                            $allowedObjects += [PSCustomObject]@{
                                Type = 'User'
                                DisplayName = "[$userId]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$userId)"
                                ID = $userId
                            }
                        }
                    }

                    # Add groups to the list - get display names
                    foreach ($groupId in $allowedGroups) {
                        try {
                            $group = Invoke-MtGraphRequest -RelativeUri "groups/$groupId" -ApiVersion 'v1.0' -ErrorAction Stop
                            $displayName = if ($group.displayName) { $group.displayName } else { $groupId }
                            $allowedObjects += [PSCustomObject]@{
                                Type = 'Group'
                                DisplayName = "[$displayName]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/$groupId)"
                                ID = $groupId
                            }
                        } catch {
                            Write-Verbose "Could not retrieve group details for $groupId`: $($_.Exception.Message)"
                            $allowedObjects += [PSCustomObject]@{
                                Type = 'Group'
                                DisplayName = "[$groupId]($($__MtSession.AdminPortalUrl.Azure)#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/$groupId)"
                                ID = $groupId
                            }
                        }
                    }

                    $restrictionSummary = "Selected users/groups ($($allowedUsers.Count) users, $($allowedGroups.Count) groups)"
                }
                '#microsoft.graph.noDeviceRegistrationMembership' {
                    $deviceJoinValue = 'None. No users can join devices.'
                    $statusValue = '✅'

                    $deviceJoinRestricted = $true
                    $restrictionSummary = 'Completely disabled (no users can join)'
                    $allowedObjects = @()
                    Write-Verbose 'Device join is disabled (no users can join)'
                }
                '#microsoft.graph.allDeviceRegistrationMembership' {
                    $deviceJoinValue = 'All users can join devices.'
                    $statusValue = '❌'

                    $deviceJoinRestricted = $false
                    $restrictionSummary = 'Unrestricted (all users can join)'
                    $allowedObjects = @()
                    Write-Verbose 'Device join is unrestricted (all users can join)'
                }
                default {
                    $deviceJoinRestricted = $false
                    $restrictionSummary = "Unknown configuration type: $allowedToJoinType"
                    $allowedObjects = @()
                    Write-Verbose "Unknown allowedToJoin type: '$allowedToJoinType'"
                    Write-Warning "Encountered unknown device registration membership type: $allowedToJoinType"
                }
            }
        } else {
            Write-Verbose 'azureADJoin.allowedToJoin settings not found in device registration policy'
            Write-Warning 'Could not find azureADJoin configuration in device registration policy'
            # If we can't determine the setting, assume unrestricted (fail-safe)
            $deviceJoinRestricted = $false
            $deviceJoinValue = 'All users can join devices.'
            $statusValue = '❌'
            $restrictionSummary = 'Configuration not found'
            $allowedObjects = @()
        }

        $statusMarkdown = "`n`n|Setting|Value|Status|`n|---|---|---|`n"
        $statusMarkdown += "|[Users may join devices to Microsoft Entra](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Overview)|$deviceJoinValue|$statusValue|`n`n"

        # Build the test result markdown
        if ($deviceJoinRestricted) {
            $testResultMarkdown += "Well done. Device join is restricted.`n`nConfiguration: $restrictionSummary"

            $testResultMarkdown += $statusMarkdown
            # Add table of allowed users/groups if any exist
            if ($allowedObjects.Count -gt 0) {
                $testResultMarkdown += "`n`n**Allowed Users and Groups:**`n`n| Type | Name |`n| --- | --- |`n"
                foreach ($obj in $allowedObjects) {
                    $testResultMarkdown += "| $($obj.Type) | $($obj.DisplayName) |`n"
                }
            }

            Add-MtTestResultDetail -Result $testResultMarkdown
        } else {
            $testResultMarkdown = "Device join is not restricted and all users may be able to join devices to Entra ID. Configuration: $restrictionSummary"

            $testResultMarkdown += $statusMarkdown
            Add-MtTestResultDetail -Result $testResultMarkdown
        }

        Write-Verbose "Test result: Device join restricted = $deviceJoinRestricted"
        return $deviceJoinRestricted

    } catch {
        Write-Verbose "Error occurred: $($_.Exception.Message)"
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
