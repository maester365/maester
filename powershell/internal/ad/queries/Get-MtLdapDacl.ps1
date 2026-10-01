function Get-MtLdapDacl {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $SearchBase,

        [string] $Filter = '(|(objectClass=organizationalUnit)(objectClass=container)(objectClass=groupPolicyContainer)(objectClass=domainDNS)(objectClass=computer)(objectClass=user)(objectClass=group))'
    )

    try {
        $attributes = @('distinguishedName', 'objectClass', 'name', 'objectSid', 'ntSecurityDescriptor')
        $securityDescriptorFlags = [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Dacl
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter $Filter -Attributes $attributes -SecurityDescriptorFlags $securityDescriptorFlags)
        $results = [System.Collections.Generic.List[object]]::new()
        foreach ($entry in $entries) {
            $descriptor = $entry.ntSecurityDescriptor
            if ($descriptor -is [byte[]]) { $descriptor = ConvertFrom-MtLdapSecurityDescriptor -RawSecurityDescriptor $descriptor }
            if ($null -eq $descriptor) { continue }
            foreach ($ace in @($descriptor.Access)) {
                $properties = [ordered]@{
                    ObjectDN = [string]$entry.DistinguishedName
                    ObjectClass = @($entry.objectClass)[-1]
                    ObjectName = [string]$entry.name
                    ObjectSid = $entry.objectSid
                }
                foreach ($property in $ace.PSObject.Properties) { $properties[$property.Name] = $property.Value }
                $results.Add([PSCustomObject]$properties) | Out-Null
            }
        }

        return @($results)
    }
    catch {
        Write-Verbose "Could not query LDAP DACL entries: $($_.Exception.Message)"
        return @()
    }
}
