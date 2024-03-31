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
            $AzureADRoles = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/directoryRoles" | Select-Object -ExpandProperty value | Where-Object { $_.displayName -in $AdminRoles } | Select-Object id, displayName
            foreach ( $AzureADRole in $AzureADRoles ) {
                $TmpUsers = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directoryRoles/$($AzureADRole.id)/members?`$select=id,userPrincipalName,userType" | Select-Object -ExpandProperty value
                Write-Verbose "Setting userType to Admin for $($TmpUsers.Count) users that are member of $($AzureADRole.displayName)."
                $TmpUsers | ForEach-Object {
                    $_.userType = "Admin"
                }
                if ( $TmpUsers ) {
                    $Users.AddRange($TmpUsers) | Out-Null
                }
                if ($TmpUsers.Count -ge $Count) {
                    Write-Verbose "Found $Count $UserType users."
                    break
                }
            }
        } else {
            $Users = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users?`$top=$($Count)&`$select=id,userPrincipalName,userType&`$filter=userType+eq+'$UserType'" | Select-Object -ExpandProperty value
        }
        Return $Users
    }

}