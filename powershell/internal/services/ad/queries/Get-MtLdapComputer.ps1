function Get-MtLdapComputer {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
    $attributes = @('distinguishedName', 'name', 'sAMAccountName', 'userAccountControl', 'operatingSystem', 'operatingSystemVersion', 'dNSHostName', 'whenCreated', 'whenChanged', 'lastLogonTimestamp', 'pwdLastSet', 'servicePrincipalName', 'primaryGroupID', 'objectSid', 'isCriticalSystemObject', 'managedBy', 'sIDHistory', 'msDS-AllowedToDelegateTo', 'msDS-AllowedToActOnBehalfOfOtherIdentity', 'mS-DS-CreatorSID')
    # Managed service accounts derive from computer but are not workstation/server inventory.
    $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(&(objectClass=computer)(!(|(objectClass=msDS-ManagedServiceAccount)(objectClass=msDS-GroupManagedServiceAccount)(objectClass=msDS-DelegatedManagedServiceAccount))))' -Attributes $attributes)
    return @($entries | ForEach-Object {
        $uac = if ($null -ne $_.userAccountControl) { ConvertFrom-MtLdapUserAccountControl -UserAccountControl ([int]$_.userAccountControl) } else { $null }
        [PSCustomObject]@{
            DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; SamAccountName = [string]$_.sAMAccountName
            Enabled = if ($null -ne $uac) { -not $uac.AccountDisabled } else { $null }; OperatingSystem = [string]$_.operatingSystem; OperatingSystemVersion = [string]$_.operatingSystemVersion
            DnsHostName = [string]$_.dNSHostName; Created = $_.whenCreated; Modified = $_.whenChanged; LastLogonDate = $_.lastLogonTimestamp
            PasswordLastSet = $_.pwdLastSet; PasswordExpired = if ($null -ne $uac) { $uac.PasswordExpired } else { $null }; PasswordNeverExpires = if ($null -ne $uac) { $uac.DontExpirePassword } else { $null }
            PasswordNotRequired = if ($null -ne $uac) { $uac.PasswordNotRequired } else { $null }; TrustedForDelegation = if ($null -ne $uac) { $uac.TrustedForDelegation } else { $null }
            TrustedToAuthForDelegation = if ($null -ne $uac) { $uac.TrustedToAuthForDelegation } else { $null }; ServicePrincipalName = [string[]]@($_.servicePrincipalName | Where-Object { $null -ne $_ })
            AllowedToDelegateTo = [string[]]@($_.'msDS-AllowedToDelegateTo' | Where-Object { $null -ne $_ })
            HasResourceBasedConstrainedDelegation = $null -ne $_.'msDS-AllowedToActOnBehalfOfOtherIdentity'
            CreatorSid = $_.'mS-DS-CreatorSID'
            'mS-DS-CreatorSID' = $_.'mS-DS-CreatorSID'
            PrimaryGroupId = $_.primaryGroupID; Sid = $_.objectSid; UserAccountControl = [int]$_.userAccountControl
            IsCriticalSystemObject = if ($null -ne $_.isCriticalSystemObject) { [bool]$_.isCriticalSystemObject } else { $null }; ManagedBy = [string]$_.managedBy; SidHistory = @($_.sIDHistory | Where-Object { $null -ne $_ })
        }
    })
}
