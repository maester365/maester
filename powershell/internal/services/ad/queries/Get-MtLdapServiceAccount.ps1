function Get-MtLdapServiceAccount {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
        $attributes = @('distinguishedName', 'name', 'sAMAccountName', 'dNSHostName', 'whenCreated', 'whenChanged', 'objectSid')
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(objectClass=msDS-GroupManagedServiceAccount)' -Attributes $attributes)
        return @($entries | ForEach-Object { [PSCustomObject]@{ DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; SamAccountName = [string]$_.sAMAccountName; DnsHostName = [string]$_.dNSHostName; Created = $_.whenCreated; Modified = $_.whenChanged; Sid = $_.objectSid } })
    }
    catch {
        Write-Verbose "Could not query LDAP group managed service accounts: $($_.Exception.Message)"
        return @()
    }
}
