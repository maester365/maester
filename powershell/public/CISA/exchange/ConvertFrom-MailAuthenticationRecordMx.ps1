<#
.SYNOPSIS
    A simple wrapper for Resolve-DnsName

.DESCRIPTION

Name                                     Type   TTL   Section    NameExchange                              Preference
----                                     ----   ---   -------    ------------                              ----------
microsoft.com                            MX     1731  Answer     microsoft-com.mail.protection.outlook.com 10

.EXAMPLE
    ConvertFrom-MailAuthenticationRecordMx -DomainName "microsoft.com"

    Returns MX records or "Failure to obtain record"
#>

Function ConvertFrom-MailAuthenticationRecordMx {
    [OutputType([Microsoft.DnsClient.Commands.DnsRecord_MX],[System.String])]
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DomainName,

        [ipaddress]$DnsServerIpAddress = "1.1.1.1",

        [switch]$QuickTimeout,

        [switch]$NoHostsFile
    )

    process {
        $mxSplat = @{
            Name         = $DomainName
            Type         = "MX"
            Server       = $DnsServerIpAddress
            NoHostsFile  = $NoHostsFile
            QuickTimeout = $QuickTimeout
            ErrorAction  = "Stop"
        }
        try{
            $mxRecords = Resolve-DnsName @mxSplat | Where-Object {$_.Type -eq "MX"}
        }catch [System.Management.Automation.CommandNotFoundException]{
            Write-Error $_
            return "Unsupported platform, Resolve-DnsName not available"
        }catch{
            Write-Error $_
            return "Failure to obtain record"
        }

        return $mxRecords
   }
}