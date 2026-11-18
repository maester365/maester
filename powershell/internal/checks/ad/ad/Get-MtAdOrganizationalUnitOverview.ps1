function Get-MtAdOrganizationalUnitOverview {
    [CmdletBinding()]
    [OutputType([object[]], [pscustomobject])]
    param([Parameter(Mandatory)] $State, [switch] $IncludeChildren)

    $ous = Get-MtAdStateCollection -State $State -Name OrganizationalUnits
    foreach ($ou in $ous) {
        if ([string]::IsNullOrWhiteSpace($ou.DistinguishedName) -or [string]::IsNullOrWhiteSpace($ou.Name)) {
            throw 'An organizational unit has missing Name or DistinguishedName metadata.'
        }
    }
    if (-not $IncludeChildren) { return $ous }
    $users = Get-MtAdStateCollection -State $State -Name Users
    $groups = Get-MtAdStateCollection -State $State -Name Groups
    $computers = Get-MtAdStateCollection -State $State -Name Computers
    # An escaped comma is part of an RDN, not a DN component separator.
    $children = @{}
    foreach ($object in @($ous) + @($users) + @($groups) + @($computers)) {
        $dn = [string]$object.DistinguishedName
        if ([string]::IsNullOrWhiteSpace($dn)) { throw 'A directory object has missing DistinguishedName metadata.' }
        $parent = $dn -replace '^(?:\\.|[^,])+,', ''
        if ($parent -ne $dn) { $children[$parent] = $true }
    }
    return [PSCustomObject]@{ Ous = $ous; WithoutSelectedDirectChildren = @($ous | Where-Object { -not $children.ContainsKey([string]$_.DistinguishedName) }) }
}
