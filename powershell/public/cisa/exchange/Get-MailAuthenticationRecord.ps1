<#
.SYNOPSIS
    Obtains and converts the mail authentication records of a domain

.DESCRIPTION
    Adapted from:
    - https://cloudbrothers.info/en/powershell-tip-resolve-spf/
    - https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Modules/Providers/ExportEXOProvider.psm1
    - https://xkln.net/blog/getting-mx-spf-dmarc-dkim-and-smtp-banners-with-powershell/
    - SPF https://datatracker.ietf.org/doc/html/rfc7208
    - DMARC https://datatracker.ietf.org/doc/html/rfc7489
    - DKIM https://datatracker.ietf.org/doc/html/rfc6376

.EXAMPLE
    Get-MailAuthenticationRecord -DomainName "microsoft.com"

    Returns an object containing the structured mail authentication objects

.LINK
    https://maester.dev/docs/commands/Get-MailAuthenticationRecord
#>
function Get-MailAuthenticationRecord {
    [OutputType([pscustomobject])]
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        # Domain name to check.
        [string]$DomainName,

        # DNS-server to use for lookup.
        [ipaddress]$DnsServerIpAddress,

        # DKIM DNS record Name to retrieve.
        [string]$DkimDnsName,

        [ValidateSet("All", "DKIM", "DMARC", "MX", "SPF")]
        # Specify which records should be retrieved. Accepted values are 'All', 'DKIM', 'DMARC', 'MX' and/or 'SPF'.
        [string[]]$Records = "All",

        # Use a shorter timeout value for the DNS lookup.
        [switch]$QuickTimeout,

        # Ignore hosts file for domain lookup.
        [switch]$NoHostsFile
    )

    begin {
        if ($Records -contains "All") {
            $all = $dkim = $dmarc = $mx = $spf = $true
        } else {
            foreach ($record in $Records) {
                Set-Variable -Name $record -Value $true
            }
        }
    }

    process {
        $recordSet = [pscustomobject]@{
            domain      = $DomainName
            mxRecords   = $null
            spfRecord   = $null
            spfLookups  = $null
            dmarcRecord = $null
            dkimRecord  = $null
        }

        if (($__MtSession.DnsCache | Where-Object { $_.domain -eq $DomainName } | Measure-Object).Count -eq 0) {
            $__MtSession.DnsCache += $recordSet
            $mtDnsCache = $recordSet
        } else {
            $mtDnsCache = $__MtSession.DnsCache | Where-Object { $_.domain -eq $DomainName }
        }

        $splat = @{
            DomainName         = $DomainName
            DnsServerIpAddress = $DnsServerIpAddress
            QuickTimeout       = $QuickTimeout
            NoHostsFile        = $NoHostsFile
        }
        # Cannot splat $DnsServerIpAddress if it is $null as it will spread $null and prohibit use the default value '1.1.1.1' of get-dns functions
        if ($DnsServerIpAddress) {
            $splat.DnsServerIpAddress = $DnsServerIpAddress
        }

        if ($mx -or $all) {
            if ($null -ne $mtDnsCache.mxRecords) {
                Write-Verbose "MX records exist in cache - Use Clear-MtDnsCache to reset"
                $recordSet.mxRecords = $mtDnsCache.mxRecords
            } else {
                $recordSet.mxRecords = ConvertFrom-MailAuthenticationRecordMx @splat
                ($__MtSession.DnsCache | Where-Object { $_.domain -eq $DomainName }).mxRecords = $recordSet.mxRecords
            }
        }

        if ($spf -or $all) {
            if ($null -ne $mtDnsCache.spfRecord) {
                Write-Verbose "SPF record exist in cache - Use Clear-MtDnsCache to reset"
                $recordSet.spfRecord = $mtDnsCache.spfRecord
                Write-Verbose "SPF record exist in cache - Skipping SPF Lookups"
                $recordSet.spfLookups = $mtDnsCache.spfLookups
            } else {
                $recordSet.spfRecord = ConvertFrom-MailAuthenticationRecordSpf @splat
                if ($recordSet.spfRecord.GetType() -ne "SPFRecord") {
                    if ($recordSet.spfRecord.terms.modifier -contains "redirect") {
                        Write-Verbose "SPF redirect modifier found, recursing"
                        $redirect = ($recordSet.spfRecord.terms | Where-Object {`
                                    $_.modifier -eq "redirect"
                            }).modifierTarget
                        Get-MailAuthenticationRecord -DomainName $redirect
                    }

                    Write-Verbose "SPF record resolved, checking lookups"
                    if ($null -ne $mtDnsCache.spfLookups) {
                        Write-Verbose "SPF Lookups records exist in cache - Use Clear-MtDnsCache to reset"
                        $recordSet.spfLookups = $mtDnsCache.spfLookups
                    } else {
                        Write-Verbose "SPF Lookups records not in cache, querying"
                        $recordSet.spfLookups = Resolve-SPFRecord -Name $DomainName -Server $DnsServerIpAddress
                        ($__MtSession.DnsCache | Where-Object { $_.domain -eq $DomainName }).spfLookups = $recordSet.spfLookups
                    }
                }
                ($__MtSession.DnsCache | Where-Object { $_.domain -eq $DomainName }).spfRecord = $recordSet.spfRecord
            }
        }

        if ($dkim -or $all) {
            if ($null -ne $mtDnsCache.dkimRecord) {
                Write-Verbose "DKIM record exist in cache - Use Clear-MtDnsCache to reset"
                $recordSet.dkimRecord = $mtDnsCache.dkimRecord
            } else {
                $recordSet.dkimRecord = ConvertFrom-MailAuthenticationRecordDkim @splat -DkimDnsName $DkimDnsName
                ($__MtSession.DnsCache | Where-Object { $_.domain -eq $DomainName }).dkimRecord = $recordSet.dkimRecord
            }
        }

        if ($dmarc -or $all) {
            if ($null -ne $mtDnsCache.dmarcRecord) {
                Write-Verbose "DMARC record exist in cache - Use Clear-MtDnsCache to reset"
                $recordSet.dmarcRecord = $mtDnsCache.dmarcRecord
            } else {
                $recordSet.dmarcRecord = ConvertFrom-MailAuthenticationRecordDmarc @splat
                ($__MtSession.DnsCache | Where-Object { $_.domain -eq $DomainName }).dmarcRecord = $recordSet.dmarcRecord
            }
        }

        return $recordSet
    }
}