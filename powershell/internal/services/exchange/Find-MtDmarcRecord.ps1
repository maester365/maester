function Find-MtDmarcRecord {
    <#
    .SYNOPSIS
    Finds the DMARC record that applies to a domain, walking up to its parent domains when needed.

    .DESCRIPTION
    Follows ScubaGear's Get-ScubaDmarcRecord, which implements the DNS tree walk of RFC 9989:

    1. Query _dmarc.<domain> and keep the TXT answers that start with v=DMARC1. If there is exactly one, it is the
       record.
    2. Otherwise walk up the parent domains, removing one label at a time (or keeping the last seven labels when
       the name has eight or more), until a single label is left or eight DNS queries have been made in total.
       At each name, exactly one answer that starts with v=DMARC1 is a record; none, or more than one, is not.
       The walk keeps going after it finds a record, so a record higher up replaces one found lower down.
    3. A record with psd=n stops the walk and is used. A record with psd=y stops the walk; the record of the
       organizational domain (the name one label below it) is used when one was found, otherwise the psd=y
       record.

    Answers are not otherwise validated: a record that matches v=DMARC1 but is not well formed is returned as it
    is, so the caller decides what a valid record is.

    .PARAMETER DomainName
    The domain to find the DMARC record for.

    .PARAMETER Cache
    A hashtable of earlier Resolve-MtDnsTxtRecord results keyed by DNS name. Pass the same hashtable for every
    domain in a run so that a parent domain shared by several domains is queried once.

    .EXAMPLE
    Find-MtDmarcRecord -DomainName 'mail.contoso.com'

    Returns the record published at _dmarc.mail.contoso.com, or the one published for a parent domain such as
    _dmarc.contoso.com.

    .OUTPUTS
    A [pscustomobject] with DomainName, PolicyDomain (the domain whose record was used, or $null), Record (the
    record, or $null) and Lookups (the Resolve-MtDnsTxtRecord results in the order they were made).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$DomainName,

        [hashtable]$Cache = @{}
    )

    $result = [pscustomobject]@{
        DomainName   = $DomainName
        PolicyDomain = $null
        Record       = $null
        Lookups      = [System.Collections.Generic.List[object]]::new()
    }

    $authorDomainLabels = @($DomainName.Split('.') | Where-Object { $_ -ne '' })
    $labels = $authorDomainLabels
    $queries = 0
    do {
        if ($queries -gt 0) {
            if ($labels.Count -ge 8) {
                $labels = @($labels[($labels.Count - 7)..($labels.Count - 1)])
            } else {
                $labels = @($labels[1..($labels.Count - 1)])
            }
        }

        $policyDomain = $labels -join '.'
        $dnsName = "_dmarc.$policyDomain"
        if (-not $Cache.ContainsKey($dnsName)) {
            $Cache[$dnsName] = Resolve-MtDnsTxtRecord -Name $dnsName
        }
        $lookup = $Cache[$dnsName]
        $result.Lookups.Add($lookup)
        $queries++
        if ($lookup.Status -eq 'NotAvailable') {
            break
        }

        $dmarcAnswers = @($lookup.Answers | Where-Object { $_ -match '^v=DMARC1' })
        if ($dmarcAnswers.Count -ne 1) {
            continue
        }

        # The record published at the domain itself is used whatever its tags.
        if ($queries -gt 1 -and $dmarcAnswers[0] -match 'psd=y\b') {
            # The organizational domain is one label below the public suffix domain. Keep its record when the
            # walk found one, otherwise use the public suffix domain's record.
            $organizationalDomainStart = $authorDomainLabels.Count - $labels.Count - 1
            $organizationalDomain = $authorDomainLabels[$organizationalDomainStart..($authorDomainLabels.Count - 1)] -join '.'
            if ($result.PolicyDomain -ne $organizationalDomain) {
                $result.PolicyDomain = $policyDomain
                $result.Record = $dmarcAnswers[0]
            }
            break
        }

        $result.PolicyDomain = $policyDomain
        $result.Record = $dmarcAnswers[0]
        if ($queries -eq 1 -or $dmarcAnswers[0] -match 'psd=n\b') {
            break
        }
    } while ($labels.Count -gt 1 -and $queries -lt 8)

    return $result
}
