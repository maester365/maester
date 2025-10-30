<#
.SYNOPSIS
  Get a list of users from the tenant

.DESCRIPTION
    This function retrieves a list of users from the tenant.
    You can specify the number of users to retrieve, the type of users (Member, Guest, Admin) and the role the users are member of.

.PARAMETER Count
    The number of users to retrieve. Default is 1.

.PARAMETER UserType
    The type of users to retrieve. Default is Member. Valid values are Member, Guest, Admin.

.PARAMETER MemberOfRole
    The role the users are member of. Default is None. Valid values are Global administrator, Application administrator, Authentication Administrator, Billing administrator, Cloud application administrator, Conditional Access administrator, Exchange administrator, Helpdesk administrator, Password administrator, Privileged authentication administrator, Privileged Role Administrator, Security administrator, SharePoint administrator, User administrator.

.EXAMPLE
    Get-MtUser -Count 5 -UserType Member
    # Get 5 Member users from the tenant.

.LINK
    https://maester.dev/docs/commands/Get-MtUser
#>
function Get-MtUser {
    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]$Count = 1,

        [Parameter()]
        [ValidateSet("Member", "Guest", "Admin", "EmergencyAccess", "BreakGlass")]
        [string]$UserType = "Member",

        [Parameter()]
        [ValidateSet("Global administrator", "Application administrator", "Authentication Administrator", "Billing administrator", "Cloud application administrator", "Conditional Access administrator", "Exchange administrator", "Helpdesk administrator", "Password administrator", "Privileged authentication administrator", "Privileged Role Administrator", "Security administrator", "SharePoint administrator", "User administrator")]
        [string]$MemberOfRole
    )

    begin {

        $Users = New-Object -TypeName 'System.Collections.ArrayList'

        # Default roles that will be queried for UserType "Admin"
        $AdminRoles = @(
            "Global administrator",
            "Application administrator",
            "Authentication Administrator",
            "Billing administrator",
            "Cloud application administrator",
            "Conditional Access administrator",
            "Exchange administrator",
            "Helpdesk administrator",
            "Password administrator",
            "Privileged authentication administrator",
            "Privileged Role Administrator",
            "Security administrator",
            "SharePoint administrator",
            "User administrator"
        )
    }

    process {

        Write-Verbose "Getting $Count $UserType users from the tenant."

        if ( $UserType -eq "Admin" ) {
            $UserType = "Member"
            if ( $MemberOfRole ) {
                Write-Verbose "Getting $UserType users that are member of $MemberOfRole."
                $AdminRoles = $MemberOfRole
            } else {
                Write-Verbose "Getting $UserType users that are member of any admin role."
            }
            $EntraIDRoles = Invoke-MtGraphRequest -ApiVersion beta 'directoryRoles' | Where-Object { $_.displayName -in $AdminRoles } | Select-Object id, displayName
            foreach ( $EntraIDRole in $EntraIDRoles ) {
                $TmpUsers = Invoke-MtGraphRequest -RelativeUri "directoryRoles/$($EntraIDRole.id)/members" -Select id, userPrincipalName, userType -OutputType Hashtable
                if ( $TmpUsers.ContainsKey('userType') ) {
                    Write-Verbose "Setting userType to Admin for $(($TmpUsers | Measure-Object).count) users that are member of $($EntraIDRole.displayName)."
                    $TmpUsers | ForEach-Object {
                        $_.userType = "Admin"
                        $Users.Add($_) | Out-Null
                        if ($Users.Count -ge $Count) {
                            Write-Verbose "Found $Count $UserType users."
                            break
                        }
                    }
                }
            }
        } elseif ( $UserType -in @("BreakGlass", "EmergencyAccess") ) {
            Write-Verbose "Getting $UserType users from the tenant."
            Write-Verbose "Get all conditional access policies."
            # Get all policies (the state of policy does not have to be enabled)
            $CAPolicies = Get-MtConditionalAccessPolicy | Where-Object { -not $_.conditions.applications.includeAuthenticationContextClassReferences }

            # Check which user object Id or group object Id is excluded from the most policies
            $PossibleEmergencyAccessUsers = $CAPolicies.conditions.users.excludeUsers | Group-Object -NoElement | Sort-Object -Property Count -Descending | Select-Object -First 2
            if ($PossibleEmergencyAccessUsers.Count -eq 2) {
                # Check if the number of excluded policies is the same for all possible users
                $EmergencyAccessUsers = $PossibleEmergencyAccessUsers | Group-Object -Property Count | Sort-Object -Property Name -Descending | Select-Object -First 1 -ExpandProperty Group
                $EmergencyAccessUsers = $EmergencyAccessUsers | Select-Object -ExpandProperty Name -Unique
            }
            $PossibleEmergencyAccessGroups = $CAPolicies.conditions.users.excludeGroups | Group-Object -NoElement | Sort-Object -Property Count -Descending | Select-Object -First 2
            if ($PossibleEmergencyAccessGroups.Count -eq 2) {
                # Check if the number of excluded policies is the same for all possible users
                $EmergencyAccessGroups = $PossibleEmergencyAccessGroups | Group-Object -Property Count | Sort-Object -Property Name -Descending | Select-Object -First 1 -ExpandProperty Group
                $EmergencyAccessGroups = $EmergencyAccessGroups | Select-Object -ExpandProperty Name -Unique
            }
            # If the number of excluded users is higher than the number of excluded groups, check the user object GUID
            $EmergencyAccessUsersCount = $CApolicies.conditions.users.excludeUsers | Where-Object { $_ -in $EmergencyAccessUsers } | Measure-Object | Select-Object -ExpandProperty Count
            $EmergencyAccessGroupsCount = $CApolicies.conditions.users.excludeGroups | Where-Object { $_ -in $EmergencyAccessGroups } | Measure-Object | Select-Object -ExpandProperty Count
            if ( $EmergencyAccessUsersCount -gt $EmergencyAccessGroupsCount ) {
                # Handling Emergency Access Users
                foreach ( $EmergencyAccessUser in $EmergencyAccessUsers ) {
                    try {
                        $TmpUsers = Invoke-MtGraphRequest -RelativeUri "users/$EmergencyAccessUser" -Select id, userPrincipalName, userType -OutputType Hashtable
                        if ( $TmpUsers.ContainsKey('userType') ) {
                            Write-Verbose "Setting userType to $UserType for $(($TmpUsers | Measure-Object).count) users that are member of EmergencyAccess."
                            $TmpUsers | ForEach-Object {
                                $_.userType = "EmergencyAccess"
                                $Users.Add($_) | Out-Null

                                if ($Users.Count -ge $Count) {
                                    Write-Verbose "Found $Count $UserType users."
                                    break
                                }
                            }
                        }
                    } catch {
                        Write-Warning -Message "Unable to retrieve user with GUID: ${EmergencyAccessUser}"
                    }
                }
            } else {
                # Handling Emergency Access Groups
                Write-Verbose "Emergency access group: $EmergencyAccessGroups"
                foreach ( $EmergencyAccessGroup in $EmergencyAccessGroups ) {
                    # Disable paging to avoid timeout of large groups which are excluded. Fix for https://github.com/maester365/maester/issues/1227
                    try {
                        $TmpUsers = Invoke-MtGraphRequest -RelativeUri "groups/$EmergencyAccessGroup/members" -Select id, userPrincipalName, userType -OutputType Hashtable -DisablePaging
                        if ( $TmpUsers.ContainsKey('userType') ) {
                            Write-Verbose "Setting userType to $UserType for $(($TmpUsers | Measure-Object).count) users that are member of EmergencyAccess."
                            $TmpUsers | ForEach-Object {
                                $_.userType = "EmergencyAccess"
                                $Users.Add($_) | Out-Null

                                if ($Users.Count -ge $Count) {
                                    Write-Verbose "Found $Count $UserType users."
                                    break
                                }
                            }
                        }
                    } catch {
                        Write-Warning -Message "Unable to retrieve group with GUID: ${EmergencyAccessUser}"
                    }
                }
            }
        } else {
            if ( $UserType -eq "Member" ) {
                $queryFilter = "userType eq 'Member'"
            } elseif ( $UserType -eq "Guest" ) {
                $queryFilter = "userType eq 'Guest'"
            } else {
                Write-Warning "UserType $($UserType) cannot be processed! Aborting!"
                throw "User can not be queried, invalid UserType: $($UserType)"
            }

            if ($Count -gt 999) {
                Write-Verbose "The maximum number of users that can be retrieved on one page is 999. Using paging to retrieve $Count users."

                $TmpUsers = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'users' -Select id, userPrincipalName, userType -Filter $queryFilter -QueryParameters @{'$top' = 999 } -OutputType Hashtable
                $Count = if ( $TmpUsers.Count -lt $Count ) { $TmpUsers.Count } else { $Count }

                Write-Verbose "Retrieved $($TmpUsers.Count) users"
                for ($i = 0; $i -lt $Count; $i++) {
                    $Users.Add($TmpUsers[$i]) | Out-Null
                }
            } else {
                $Users = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'users' -Select id, userPrincipalName, userType -Filter $queryFilter -QueryParameters @{'$top' = $Count } -DisablePaging -OutputType Hashtable
                $Users = $Users['value']
            }
        }

        return $Users
    }
}