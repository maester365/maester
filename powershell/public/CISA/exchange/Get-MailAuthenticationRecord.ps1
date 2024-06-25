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
            $recordSet.mxRecords = ConvertFrom-MailAuthenticationRecordMx @splat
        }

        if($spf -or $all){
            ###check for 10* include, a, mx, ptr, exists
            $recordSet.spfRecord = ConvertFrom-MailAuthenticationRecordSpf @splat
            if($recordSet.spfRecord -ne "Failure to obtain record"){
                $recordSet.spfLookups = Resolve-SPFRecord -Name $DomainName -Server $DnsServerIpAddress
            }
        }

        if($dkim -or $all){
            $recordSet.dkimRecord = ConvertFrom-MailAuthenticationRecordDkim @splat -DkimSelector $DkimSelector
        }

        if($dmarc -or $all){
            $recordSet.dmarcRecord = ConvertFrom-MailAuthenticationRecordDmarc @splat
        }

        return $recordSet
    }
}