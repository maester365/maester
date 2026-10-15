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
        return @($entries | ForEach-Object {
            $trustAttributesValue = if ($null -ne $_.trustAttributes) { [int]$_.trustAttributes } else { 0 }
            $trustDirectionValue = if ($null -ne $_.trustDirection) { [int]$_.trustDirection } else { 0 }
            $trustTypeValue = if ($null -ne $_.trustType) { [int]$_.trustType } else { 0 }

            $direction = switch ($trustDirectionValue) {
                1 { 'Inbound' }
                2 { 'Outbound' }
                3 { 'Bidirectional' }
                default { $trustDirectionValue }
            }

            $type = switch ($trustTypeValue) {
                1 { 'External Downlevel' }
                2 { 'Domain Uplevel' }
                3 { 'MIT Kerberos' }
                4 { 'DCE' }
                default { $trustTypeValue }
            }

            [PSCustomObject]@{
                Name = [string]$_.name
                DistinguishedName = [string]$_.DistinguishedName
                TrustPartner = [string]$_.trustPartner
                Target = [string]$_.trustPartner
                TrustType = $type
                TrustDirection = $_.trustDirection
                Direction = $direction
                TrustAttributes = $_.trustAttributes
                IntraForest = [bool]($trustAttributesValue -band 0x20)
                Quarantined = [bool]($trustAttributesValue -band 0x4)
                SelectiveAuthentication = [bool]($trustAttributesValue -band 0x10)
                Sid = $_.securityIdentifier
                Created = $_.whenCreated
                Modified = $_.whenChanged
            }
        })
    }
    catch {
        Write-Verbose "Could not query LDAP trust objects: $($_.Exception.Message)"
        return @()
    }
}
