function Get-MtLdapUser {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
        $attributes = @('distinguishedName', 'name', 'sAMAccountName', 'userAccountControl', 'adminCount', 'homeDirectory', 'badPasswordTime', 'lastLogonTimestamp', 'lockoutTime', 'logonHours', 'userWorkstations', 'managedBy', 'manager', 'pwdLastSet', 'profilePath', 'scriptPath', 'objectSid', 'sIDHistory', 'servicePrincipalName', 'whenCreated', 'whenChanged', 'isCriticalSystemObject')
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(&(objectClass=user)(!(objectClass=computer)))' -Attributes $attributes)
        return @($entries | ForEach-Object {
            $uac = if ($null -ne $_.userAccountControl) { ConvertFrom-MtLdapUserAccountControl -UserAccountControl ([int]$_.userAccountControl) } else { $null }
            [PSCustomObject]@{
                DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; SamAccountName = [string]$_.sAMAccountName; Enabled = if ($null -ne $uac) { -not $uac.AccountDisabled } else { $null }
                AdminCount = $_.adminCount; CannotChangePassword = if ($null -ne $uac) { $uac.PasswordCannotChange } else { $null }; DoesNotRequirePreAuth = if ($null -ne $uac) { $uac.DontRequirePreauth } else { $null }
                HomeDirectory = [string]$_.homeDirectory; LastBadPasswordAttempt = $_.badPasswordTime; LastLogonDate = $_.lastLogonTimestamp
                LockedOut = ([long]$_.lockoutTime -gt 0); LogonHours = $_.logonHours; LogonWorkstations = [string]$_.userWorkstations
                ManagedBy = [string]$_.managedBy; Manager = [string]$_.manager; PasswordExpired = if ($null -ne $uac) { $uac.PasswordExpired } else { $null }; PasswordLastSet = $_.pwdLastSet
                PasswordNeverExpires = if ($null -ne $uac) { $uac.DontExpirePassword } else { $null }; PasswordNotRequired = if ($null -ne $uac) { $uac.PasswordNotRequired } else { $null }; ProfilePath = [string]$_.profilePath
                ScriptPath = [string]$_.scriptPath; Sid = $_.objectSid; SidHistory = @($_.sIDHistory | Where-Object { $null -ne $_ }); ServicePrincipalName = [string[]]@($_.servicePrincipalName | Where-Object { $null -ne $_ })
                TrustedForDelegation = if ($null -ne $uac) { $uac.TrustedForDelegation } else { $null }; TrustedToAuthForDelegation = if ($null -ne $uac) { $uac.TrustedToAuthForDelegation } else { $null }; UseDESKeyOnly = if ($null -ne $uac) { $uac.UseDesKeyOnly } else { $null }
                UserAccountControl = if ($null -ne $_.userAccountControl) { [int]$_.userAccountControl } else { $null }; Created = $_.whenCreated; Modified = $_.whenChanged; IsCriticalSystemObject = if ($null -ne $_.isCriticalSystemObject) { [bool]$_.isCriticalSystemObject } else { $null }
            }
        })
    }
    catch {
        Write-Verbose "Could not query LDAP user objects: $($_.Exception.Message)"
        return @()
    }
}
