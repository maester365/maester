﻿<#
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [OutputType([PSCustomObject],[System.String])]
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
            if($isWindows){
                $mxRecords = Resolve-DnsName @mxSplat | Where-Object {$_.Type -eq "MX"}
                $mxRecords = $mxRecords|ConvertTo-Json|ConvertFrom-Json
            }else{
                Write-Verbose "Is not Windows, checking for Resolve-Dns"
                $cmdletCheck = Get-Command "Resolve-Dns"
                if($cmdletCheck){
                    Write-Verbose "Resolve-Dns exists, querying records"
                    $mxSplatAlt = @{
                        Query       = $mxSplat.Name
                        QueryType   = $mxSplat.Type
                        NameServer  = $mxSplat.Server
                        ErrorAction = $mxSplat.ErrorAction
                    }
                    $answers = (Resolve-Dns @mxSplatAlt).Answers | Where-Object {$_.RecordType -eq "MX"}
                    $mxRecords = $answers | ForEach-Object {
                        [PSCustomObject]@{
                            Name         = $_.DomainName
                            NameExchange = $_.Exchange
                            Type         = $_.RecordType
                            TTL          = $_.TimeToLive
                            Preference   = $_.Preference
                        }
                    }
                }else{
                    Write-Error "`nFor non-Windows platforms, please install DnsClient-PS module."
                    Write-Host "`n    Install-Module DnsClient-PS -Scope CurrentUser`n" -ForegroundColor Yellow
                    return "Missing dependency, Resolve-Dns not available"
                }
            }
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