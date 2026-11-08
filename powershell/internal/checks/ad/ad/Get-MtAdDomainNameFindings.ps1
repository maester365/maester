function Get-MtAdDomainNameFindings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Internal helper returns a collection of domain-name findings.')]
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Forest, [ValidateSet('Dns', 'Netbios')] [string] $Kind)

    $partitions = @($Forest.DomainPartitions)
    if ($partitions.Count -eq 0 -or @($Forest.Domains).Count -ne $partitions.Count) {
        throw 'Complete forest domain partition metadata is required to validate names.'
    }
    $findings = [System.Collections.Generic.List[string]]::new()
    foreach ($partition in $partitions) {
        if (-not $partition.DistinguishedName -or -not $partition.DnsRoot -or -not $partition.NetBIOSName) {
            throw 'A forest domain partition has missing DN, DNS root or NetBIOS name.'
        }
        $name = if ($Kind -eq 'Dns') { [string]$partition.DnsRoot } else { [string]$partition.NetBIOSName }
        if ($Kind -eq 'Dns') {
            try { $ascii = [System.Globalization.IdnMapping]::new().GetAscii($name) } catch { $ascii = '' }
            $valid = $ascii.Length -le 253 -and $ascii.Length -gt 0
            foreach ($label in @($ascii -split '\.')) {
                if ($label.Length -gt 63 -or $label -cnotmatch '^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$') { $valid = $false }
            }
        } else {
            $valid = $name.Length -le 15 -and $name.Length -gt 0 -and $name -notmatch '[\\/:*?"<>|\.]' -and $name -notmatch '^\s|\s$'
        }
        if (-not $valid) { $findings.Add("$name ($($partition.DistinguishedName))") }
    }
    return $findings.ToArray()
}
