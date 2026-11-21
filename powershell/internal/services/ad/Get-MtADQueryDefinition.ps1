function Get-MtADQueryDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('User', 'Computer', 'Group', 'OrganizationalUnit', 'Gpo')]
        [string] $Name
    )

    # Starter queries, not replacements for the legacy collectors' richer projections.
    $definitions = @{
        User = @{ Filter = '(&(objectClass=user)(!(objectClass=computer)))'; Attributes = @('objectGUID', 'name', 'sAMAccountName', 'userAccountControl', 'primaryGroupID') }
        Computer = @{ Filter = '(objectClass=computer)'; Attributes = @('objectGUID', 'name', 'sAMAccountName', 'dNSHostName', 'userAccountControl') }
        Group = @{ Filter = '(objectClass=group)'; Attributes = @('objectGUID', 'name', 'sAMAccountName', 'groupType') }
        OrganizationalUnit = @{ Filter = '(objectClass=organizationalUnit)'; Attributes = @('objectGUID', 'name', 'gPLink', 'gPOptions') }
        Gpo = @{ Filter = '(objectClass=groupPolicyContainer)'; Attributes = @('objectGUID', 'name', 'displayName', 'gPCFileSysPath', 'versionNumber') }
    }
    return $definitions[$Name]
}
