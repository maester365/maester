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

#>
function Get-MtUser {
    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]$Count = 1,

        [Parameter()]
        [ValidateSet("Member", "Guest", "Admin")]
        [string]$UserType = "Member",

        [Parameter()]
        [ValidateSet("Global administrator", "Application administrator", "Authentication Administrator", "Billing administrator", "Cloud application administrator", "Conditional Access administrator", "Exchange administrator", "Helpdesk administrator", "Password administrator", "Privileged authentication administrator", "Privileged Role Administrator", "Security administrator", "SharePoint administrator", "User administrator")]
        [string]$MemberOfRole
    )

    process {
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

        Write-Verbose "Getting $Count $UserType users from the tenant."
        $Users = New-Object -TypeName 'System.Collections.ArrayList'

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
                    Write-Verbose "Setting userType to Admin for $($TmpUsers.Count) users that are member of $($EntraIDRole.displayName)."
                    $TmpUsers | ForEach-Object {
                        $_.userType = "Admin"
                        $Users.Add($_) | Out-Null
                    }
                    if ($Users.Count -ge $Count) {
                        Write-Verbose "Found $Count $UserType users."
                        break
                    }
                }
            }
        } else {
            if ($Count -gt 999) {
                Write-Verbose "The maximum number of users that can be retrieved on one page is 999. Using paging to retrieve $Count users."
                $TmpUsers = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'users' -Select id, userPrincipalName, userType -Filter "userType eq 'Member'" -QueryParameters @{'$top' = 999 } -OutputType Hashtable
                $Count = if ( $TmpUsers.Count -lt $Count ) { $TmpUsers.Count } else { $Count }
                Write-Verbose "Retrieved $($TmpUsers.Count) users"
                for ($i = 0; $i -lt $Count; $i++) {
                    $Users.Add($TmpUsers[$i]) | Out-Null
                }
            } else {
                $Users = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'users' -Select id, userPrincipalName, userType -Filter "userType eq 'Member'" -QueryParameters @{'$top' = $Count } -DisablePaging -OutputType Hashtable
                if ( $EntraIDRoles.ContainsKey('value') ) {
                    $Users = $Users['value']
                }
            }
        }
        Return $Users
    }
}