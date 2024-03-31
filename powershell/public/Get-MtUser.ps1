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