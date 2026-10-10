function ConvertFrom-MtLdapSecurityDescriptor {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [byte[]] $RawSecurityDescriptor
    )

    function Resolve-IdentityReference {
        param(
            [AllowNull()]
            [System.Security.Principal.SecurityIdentifier] $Sid
        )

        if ($null -eq $Sid) {
            return $null
        }

        try {
            return $Sid.Translate([System.Security.Principal.NTAccount]).Value
        }
        catch {
            return $Sid.Value
        }
    }

    function Get-InheritanceTypeName {
        param(
            [System.Security.AccessControl.AceFlags] $AceFlags
        )

        if (($AceFlags -band [System.Security.AccessControl.AceFlags]::ContainerInherit) -or ($AceFlags -band [System.Security.AccessControl.AceFlags]::ObjectInherit)) {
            if ($AceFlags -band [System.Security.AccessControl.AceFlags]::InheritOnly) {
                return 'Descendents'
            }

            return 'All'
        }

        return 'None'
    }

    function Convert-AceRecord {
        param($Ace)

        $sid = $null
        $identityReference = $null
        $accessMask = 0
        $objectType = [guid]::Empty.ToString()
        $inheritedObjectType = [guid]::Empty.ToString()

        if ($Ace -is [System.Security.AccessControl.KnownAce]) {
            $sid = $Ace.SecurityIdentifier.Value
            $identityReference = Resolve-IdentityReference -Sid $Ace.SecurityIdentifier
            $accessMask = $Ace.AccessMask
        }

        if ($Ace -is [System.Security.AccessControl.ObjectAce]) {
            if ($Ace.ObjectAceType -ne [guid]::Empty) {
                $objectType = $Ace.ObjectAceType.ToString()
            }

            if ($Ace.InheritedObjectAceType -ne [guid]::Empty) {
                $inheritedObjectType = $Ace.InheritedObjectAceType.ToString()
            }
        }

        $accessControlType = switch ($Ace.AceType) {
            'AccessAllowed' { 'Allow' }
            'AccessAllowedObject' { 'Allow' }
            'AccessDenied' { 'Deny' }
            'AccessDeniedObject' { 'Deny' }
            'SystemAudit' { 'Audit' }
            'SystemAuditObject' { 'Audit' }
            default { $Ace.AceType.ToString() }
        }

        $activeDirectoryRights = try {
            ([System.DirectoryServices.ActiveDirectoryRights]$accessMask).ToString()
        }
        catch {
            [string]$accessMask
        }

        return [PSCustomObject]@{
            AccessControlType     = $accessControlType
            AccessMask            = $accessMask
            AceFlags              = $Ace.AceFlags.ToString()
            AceType               = $Ace.AceType.ToString()
            ActiveDirectoryRights = $activeDirectoryRights
            IdentityReference     = $identityReference
            InheritanceType       = Get-InheritanceTypeName -AceFlags $Ace.AceFlags
            InheritedObjectType   = $inheritedObjectType
            IsInherited           = [bool]($Ace.AceFlags -band [System.Security.AccessControl.AceFlags]::Inherited)
            ObjectType            = $objectType
            Sid                   = $sid
        }
    }

    $descriptor = [System.Security.AccessControl.RawSecurityDescriptor]::new($RawSecurityDescriptor, 0)
    $ownerReference = Resolve-IdentityReference -Sid $descriptor.Owner
    $groupReference = Resolve-IdentityReference -Sid $descriptor.Group
    $daclEntries = [System.Collections.Generic.List[object]]::new()
    $saclEntries = [System.Collections.Generic.List[object]]::new()

    if ($null -ne $descriptor.DiscretionaryAcl) {
        foreach ($ace in $descriptor.DiscretionaryAcl) {
            $daclEntries.Add((Convert-AceRecord -Ace $ace)) | Out-Null
        }
    }

    if ($null -ne $descriptor.SystemAcl) {
        foreach ($ace in $descriptor.SystemAcl) {
            $saclEntries.Add((Convert-AceRecord -Ace $ace)) | Out-Null
        }
    }

    return [PSCustomObject]@{
        Access = @($daclEntries)
        Audit  = @($saclEntries)
        Dacl   = @($daclEntries)
        Group  = [PSCustomObject]@{
            IdentityReference = $groupReference
            Sid               = if ($null -ne $descriptor.Group) { $descriptor.Group.Value } else { $null }
        }
        Owner  = [PSCustomObject]@{
            IdentityReference = $ownerReference
            Sid               = if ($null -ne $descriptor.Owner) { $descriptor.Owner.Value } else { $null }
        }
        Sacl   = @($saclEntries)
        Sddl   = $descriptor.GetSddlForm([System.Security.AccessControl.AccessControlSections]::All)
    }
}
