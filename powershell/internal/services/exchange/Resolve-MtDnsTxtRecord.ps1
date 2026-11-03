function Resolve-MtDnsTxtRecord {
    <#
    .SYNOPSIS
    Returns the TXT records published at a DNS name, without filtering them.

    .DESCRIPTION
    Uses Resolve-DnsName on Windows and Resolve-Dns from the DnsClient-PS module on macOS and Linux. Each TXT
    record is returned as one string: a record that DNS splits into several character strings is joined back
    together with no separator, as ScubaGear's Invoke-RobustDnsTxt does.

    Status is one of:
    - Success: the query was answered. Answers holds the TXT records, and is empty when the name has none.
    - NXDomain: the name does not exist.
    - Error: the query failed. Error holds the message.
    - NotAvailable: no DNS resolver command is available on this platform. Error says which one is missing.

    .PARAMETER Name
    The DNS name to query, for example _dmarc.contoso.com.

    .EXAMPLE
    Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

    Returns the TXT records published at _dmarc.contoso.com.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $dnsResult = Resolve-MtDnsRecord -Name $Name -Type TXT
    return [pscustomobject]@{
        Name    = $dnsResult.Name
        Status  = $dnsResult.Status
        Answers = [string[]]@($dnsResult.Answers | ForEach-Object { $_.Value })
        Error   = $dnsResult.Error
    }
}
