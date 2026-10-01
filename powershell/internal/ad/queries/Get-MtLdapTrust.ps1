function Get-MtLdapTrust {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
        $attributes = @('distinguishedName', 'name', 'trustPartner', 'trustType', 'trustDirection', 'trustAttributes', 'securityIdentifier', 'whenCreated', 'whenChanged')
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(objectClass=trustedDomain)' -Attributes $attributes)
        return @($entries | ForEach-Object { [PSCustomObject]@{ Name = [string]$_.name; DistinguishedName = [string]$_.DistinguishedName; TrustPartner = [string]$_.trustPartner; TrustType = $_.trustType; TrustDirection = $_.trustDirection; TrustAttributes = $_.trustAttributes; Sid = $_.securityIdentifier; Created = $_.whenCreated; Modified = $_.whenChanged } })
    }
    catch {
        Write-Verbose "Could not query LDAP trust objects: $($_.Exception.Message)"
        return @()
    }
}
