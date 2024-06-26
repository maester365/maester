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
#>

Function Get-MailAuthenticationRecord {
    [OutputType([pscustomobject])]
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            [uri]::CheckHostName($_) -eq "Dns"
        })]
        [string]$DomainName,

        [ipaddress]$DnsServerIpAddress = "1.1.1.1",

        [string]$DkimSelector = "selector1",

        [ValidateSet("All","DKIM","DMARC","MX","SPF")]
        [string[]]$Records = "All",

        [switch]$QuickTimeout,

        [switch]$NoHostsFile
    )

    begin {
        if($Records -contains "All"){
            $all = $dkim = $dmarc = $mx = $spf = $true
        }else{
            foreach($record in $Records){
                Set-Variable -Name $record -Value $true
            }
        }
    }

    process {
        $recordSet = [pscustomobject]@{
            mxRecords   = $null
            spfRecord   = $null
            spfLookups  = $null
            dmarcRecord = $null
            dkimRecord  = $null
        }

        $splat = @{
            DomainName         = $DomainName
            DnsServerIpAddress = $DnsServerIpAddress
            QuickTimeout       = $QuickTimeout
            NoHostsFile        = $NoHostsFile
        }

        if($mx -or $all){
            if($null -ne $__MtSession.DnsCache.mxRecords){
                Write-Verbose "MX records exist in cache - Use Clear-MtDnsCache to reset"
                $recordSet.mxRecords = $__MtSession.DnsCache.mxRecords
            }else{
                $recordSet.mxRecords = ConvertFrom-MailAuthenticationRecordMx @splat
                $__MtSession.DnsCache.mxRecords = $recordSet.mxRecords
            }
        }

        if($spf -or $all){
            if($null -ne $__MtSession.DnsCache.spfRecord){
                Write-Verbose "SPF record exist in cache - Use Clear-MtDnsCache to reset"
                Write-Verbose "SPF record exist in cache - Skipping SPF Lookups"
                $recordSet.spfRecord = $__MtSession.DnsCache.spfRecord
            }else{
                $recordSet.spfRecord = ConvertFrom-MailAuthenticationRecordSpf @splat
                if($recordSet.spfRecord -ne "Failure to obtain record"){
                    if($null -ne $__MtSession.DnsCache.spfLookups){
                        Write-Verbose "SPF Lookups records exist in cache - Use Clear-MtDnsCache to reset"
                        $recordSet.spfLookups = $__MtSession.DnsCache.spfLookups
                    }else{
                        $recordSet.spfLookups = Resolve-SPFRecord -Name $DomainName -Server $DnsServerIpAddress
                        $__MtSession.DnsCache.spfLookups = $recordSet.spfLookups
                    }
                }
                $__MtSession.DnsCache.spfRecord = $recordSet.spfRecord
            }
        }

        if($dkim -or $all){
            if($null -ne $__MtSession.DnsCache.dkimRecord){
                Write-Verbose "DKIM record exist in cache - Use Clear-MtDnsCache to reset"
                $recordSet.dkimRecord = $__MtSession.DnsCache.dkimRecord
            }else{
                $recordSet.dkimRecord = ConvertFrom-MailAuthenticationRecordDkim @splat -DkimSelector $DkimSelector
                $__MtSession.DnsCache.dkimRecord = $recordSet.dkimRecord
            }
        }

        if($dmarc -or $all){
            if($null -ne $__MtSession.DnsCache.dmarcRecord){
                Write-Verbose "DMARC record exist in cache - Use Clear-MtDnsCache to reset"
                $recordSet.dmarcRecord = $__MtSession.DnsCache.dmarcRecord
            }else{
                $recordSet.dmarcRecord = ConvertFrom-MailAuthenticationRecordDmarc @splat
                $__MtSession.DnsCache.dmarcRecord = $recordSet.dmarcRecord
            }
        }

        return $recordSet
    }
}