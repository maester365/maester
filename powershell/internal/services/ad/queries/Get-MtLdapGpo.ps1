function Get-MtLdapGpo {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
    $attributes = @('distinguishedName', 'name', 'displayName', 'whenCreated', 'whenChanged', 'flags', 'ntSecurityDescriptor', 'gPCWQLFilter', 'gPCFileSysPath', 'versionNumber')
    $securityDescriptorFlags = [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Dacl
    $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(objectClass=groupPolicyContainer)' -Attributes $attributes -SecurityDescriptorFlags $securityDescriptorFlags)
    return @($entries | ForEach-Object {
        $entry = $_
        # LDAP exposes a signed 32-bit value; GPT.INI stores the same bits as unsigned.
        $version = if ($null -ne $_.versionNumber) { [long]$_.versionNumber -band 0xffffffffL } else { $null }
        $idText = ([string]$_.name).Trim('{}')
        $id = $idText
        try { $id = [guid]$idText } catch { Write-Verbose "GPO '$($entry.name)' does not contain a valid GUID name." }
        [PSCustomObject]@{
            Id = $id; DisplayName = [string]$_.displayName; DistinguishedName = [string]$_.DistinguishedName; Created = $_.whenCreated; Modified = $_.whenChanged
            Flags = $_.flags; Owner = $_.ntSecurityDescriptor.Owner.IdentityReference; ntSecurityDescriptor = $_.ntSecurityDescriptor; WmiFilter = [string]$_.gPCWQLFilter; GpcFileSysPath = [string]$_.gPCFileSysPath
            VersionNumber = $version
            UserVersion = if ($null -ne $version) { ($version -shr 16) -band 0xffff } else { $null }
            ComputerVersion = if ($null -ne $version) { $version -band 0xffff } else { $null }
        }
    })
}
