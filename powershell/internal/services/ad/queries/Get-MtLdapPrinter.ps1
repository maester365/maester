function Get-MtLdapPrinter {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(objectClass=printQueue)' -Attributes @('distinguishedName', 'name', 'serverName', 'location'))
        return @($entries | ForEach-Object { [PSCustomObject]@{ DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; ServerName = [string]$_.serverName; Location = [string]$_.location } })
    }
    catch {
        Write-Verbose "Could not query LDAP printer objects: $($_.Exception.Message)"
        return @()
    }
}
