function Get-MtAdOrganizationalUnitOverview {
    [CmdletBinding()]
    [OutputType([object[]], [pscustomobject])]
    param([Parameter(Mandatory)] $State, [switch] $IncludeChildren)

    if ($null -eq $State -or $null -eq $State.PSObject.Properties['OrganizationalUnits'] -or $null -eq $State.OrganizationalUnits) {
        throw 'Active Directory OrganizationalUnits data is unavailable.'
    }
    $ous = @($State.OrganizationalUnits)
    foreach ($ou in $ous) {
        if ([string]::IsNullOrWhiteSpace($ou.DistinguishedName) -or [string]::IsNullOrWhiteSpace($ou.Name)) {
            throw 'An organizational unit has missing Name or DistinguishedName metadata.'
        }
    }
    if (-not $IncludeChildren) { return $ous }
    foreach ($category in @('Users', 'Groups', 'Computers')) {
        if ($null -eq $State.PSObject.Properties[$category] -or $null -eq $State.$category) {
            throw "Active Directory $category data is unavailable."
        }
    }
    # An escaped comma is part of an RDN, not a DN component separator.
    $children = @{}
    foreach ($object in @($ous) + @($State.Users) + @($State.Groups) + @($State.Computers)) {
        $dn = [string]$object.DistinguishedName
        if ([string]::IsNullOrWhiteSpace($dn)) { throw 'A directory object has missing DistinguishedName metadata.' }
        $parent = $dn -replace '^(?:\\.|[^,])+,', ''
        if ($parent -ne $dn) { $children[$parent] = $true }
    }
    return [PSCustomObject]@{ Ous = $ous; WithoutSelectedDirectChildren = @($ous | Where-Object { -not $children.ContainsKey([string]$_.DistinguishedName) }) }
}
