function Get-MtLdapServiceAccount {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
    $attributes = @('distinguishedName', 'name', 'sAMAccountName', 'dNSHostName', 'whenCreated', 'whenChanged', 'objectSid', 'objectClass', 'msDS-DelegatedMSAState')
    $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(|(objectClass=msDS-ManagedServiceAccount)(objectClass=msDS-GroupManagedServiceAccount)(objectClass=msDS-DelegatedManagedServiceAccount))' -Attributes $attributes)
    return @($entries | ForEach-Object { [PSCustomObject]@{ DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; SamAccountName = [string]$_.sAMAccountName; DnsHostName = [string]$_.dNSHostName; Created = $_.whenCreated; Modified = $_.whenChanged; Sid = $_.objectSid; ObjectClass = @($_.objectClass); DelegatedMsaState = $_.'msDS-DelegatedMSAState' } })
}
