function Get-MtAdSubnetInventory {
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory)] $State)

    if ($null -eq $State -or $null -eq $State.PSObject.Properties['Subnets'] -or $null -eq $State.Subnets) {
        throw 'Active Directory Subnets data is unavailable.'
    }

    $entries = foreach ($subnet in @($State.Subnets)) {
        $cidr = [string]$subnet.Name
        if ([string]::IsNullOrWhiteSpace($subnet.DistinguishedName)) {
            throw "Subnet '$cidr' has missing DistinguishedName metadata."
        }
        if ($cidr -notmatch '^([^/]+)/([0-9]{1,3})$') {
            throw "Invalid subnet CIDR '$cidr'."
        }
        $addressText = $Matches[1]
        $prefix = [int]$Matches[2]
        $address = $null
        if (-not [System.Net.IPAddress]::TryParse($addressText, [ref]$address) -or
            $addressText -match '%' -or
            ($address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and $addressText -notmatch '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') -or
            $address.AddressFamily -notin @([System.Net.Sockets.AddressFamily]::InterNetwork, [System.Net.Sockets.AddressFamily]::InterNetworkV6)) {
            throw "Invalid subnet address '$cidr'."
        }
        $ipv4 = $address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
        if ($prefix -gt $(if ($ipv4) { 32 } else { 128 })) {
            throw "Invalid subnet prefix '$cidr'."
        }
        $bytes = $address.GetAddressBytes()
        $private = $ipv4 -and (($bytes[0] -eq 10) -or ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or ($bytes[0] -eq 192 -and $bytes[1] -eq 168))
        [PSCustomObject]@{
            Subnet = $subnet
            Cidr = $cidr
            Address = $address
            Prefix = $prefix
            IsIpv4 = $ipv4
            IsRfc1918 = $private
            # A range belongs wholly to RFC1918 only if its prefix covers no addresses outside the block.
            IsRfc1918Subset = $private -and (($bytes[0] -eq 10 -and $prefix -ge 8) -or
                ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31 -and $prefix -ge 12) -or
                ($bytes[0] -eq 192 -and $bytes[1] -eq 168 -and $prefix -ge 16))
        }
    }
    return @($entries)
}
