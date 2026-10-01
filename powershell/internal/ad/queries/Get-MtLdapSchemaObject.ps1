function Get-MtLdapSchemaObject {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $SchemaNamingContext
    )

    try {
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SchemaNamingContext -Scope Subtree -Filter '(objectClass=*)' -Attributes @('distinguishedName', 'name', 'objectClass', 'whenCreated', 'objectVersion'))
        return @($entries | ForEach-Object { [PSCustomObject]@{ DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; ObjectClass = @($_.objectClass | Where-Object { $null -ne $_ }); WhenCreated = $_.whenCreated; ObjectVersion = $_.objectVersion } })
    }
    catch {
        Write-Verbose "Could not query LDAP schema objects: $($_.Exception.Message)"
        return @()
    }
}
