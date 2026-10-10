function Get-MtLdapGpo {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
        $attributes = @('distinguishedName', 'name', 'displayName', 'whenCreated', 'whenChanged', 'flags', 'ntSecurityDescriptor', 'gPCWQLFilter', 'gPCFileSysPath', 'versionNumber')
        $securityDescriptorFlags = [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Dacl
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(objectClass=groupPolicyContainer)' -Attributes $attributes -SecurityDescriptorFlags $securityDescriptorFlags)
        return @($entries | ForEach-Object {
            $entry = $_
            $version = [int]$_.versionNumber
            $idText = ([string]$_.name).Trim('{}')
            $id = $idText
            try { $id = [guid]$idText } catch { Write-Verbose "GPO '$($entry.name)' does not contain a valid GUID name." }
            [PSCustomObject]@{
                Id = $id; DisplayName = [string]$_.displayName; DistinguishedName = [string]$_.DistinguishedName; Created = $_.whenCreated; Modified = $_.whenChanged
                Flags = $_.flags; Owner = $_.ntSecurityDescriptor.Owner.IdentityReference; ntSecurityDescriptor = $_.ntSecurityDescriptor; WmiFilter = [string]$_.gPCWQLFilter; GpcFileSysPath = [string]$_.gPCFileSysPath
                VersionNumber = $version; UserVersion = (($version -shr 16) -band 0xffff); ComputerVersion = ($version -band 0xffff)
            }
        })
    }
    catch {
        Write-Verbose "Could not query LDAP group policy containers: $($_.Exception.Message)"
        return @()
    }
}
