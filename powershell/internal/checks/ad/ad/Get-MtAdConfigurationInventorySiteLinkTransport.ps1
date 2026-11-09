function Get-MtAdConfigurationInventorySiteLinkTransport {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Configuration)

    $rows = @()
    foreach ($link in @($Configuration.SiteLinks)) {
        $match = [regex]::Match([string]$link.DistinguishedName, '(?i)^CN=(?:\\.|[^,])+,CN=(IP|SMTP),CN=Inter-Site Transports,')
        $transport = if ($match.Success) { $match.Groups[1].Value } else { '' }
        if ($transport -notin @('IP', 'SMTP')) { throw "Unknown site link transport for $($link.Name): $($link.DistinguishedName)." }
        $rows += [pscustomobject]@{
            Name = $link.Name
            Transport = $transport.ToUpperInvariant()
            Cost = $link.cost
            Interval = $link.ReplicationFrequencyInMinutes
            Sites = (@($link.siteList | Where-Object { $null -ne $_ }) -join ', ')
            DistinguishedName = $link.DistinguishedName
        }
    }
    return $rows
}
