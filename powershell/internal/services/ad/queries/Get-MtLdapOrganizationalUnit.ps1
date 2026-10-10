function Get-MtLdapOrganizationalUnit {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
        $attributes = @('distinguishedName', 'name', 'whenCreated', 'whenChanged', 'managedBy', 'description', 'gPLink', 'gPOptions')
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(objectClass=organizationalUnit)' -Attributes $attributes)
        return @($entries | ForEach-Object { [PSCustomObject]@{ DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; Created = $_.whenCreated; Modified = $_.whenChanged; ManagedBy = [string]$_.managedBy; Description = [string]$_.description; GpLink = [string]$_.gPLink; GpOptions = $_.gPOptions } })
    }
    catch {
        Write-Verbose "Could not query LDAP organizational units: $($_.Exception.Message)"
        return @()
    }
}
