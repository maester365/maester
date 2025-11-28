<#
.SYNOPSIS
    A simple wrapper for Resolve-DnsName

.DESCRIPTION
    ```
    Name                                     Type   TTL   Section    NameExchange                              Preference
    ----                                     ----   ---   -------    ------------                              ----------
    microsoft.com                            MX     1731  Answer     microsoft-com.mail.protection.outlook.com 10
    ```

.EXAMPLE
    ConvertFrom-MailAuthenticationRecordMx -DomainName "microsoft.com"

    Returns MX records or "Failure to obtain record"

.LINK
    https://maester.dev/docs/commands/ConvertFrom-MailAuthenticationRecordMx
#>
function ConvertFrom-MailAuthenticationRecordMx {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [OutputType([PSCustomObject], [System.String])]
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        # Domain name to check.
        [string]$DomainName,

        # DNS-server to use for lookup.
        [ipaddress]$DnsServerIpAddress,

        # Use a shorter timeout value for the DNS lookup.
        [switch]$QuickTimeout,

        # Ignore hosts file for domain lookup.
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
        try {
            if ( $isWindows -or $PSVersionTable.PSEdition -eq "Desktop" ) {
                $mxRecords = Resolve-DnsName @mxSplat | Where-Object { $_.Type -eq "MX" }
                $mxRecords = $mxRecords | ConvertTo-Json | ConvertFrom-Json
            } else {
                Write-Verbose "Is not Windows, checking for Resolve-Dns"
                $cmdletCheck = Get-Command "Resolve-Dns" -ErrorAction SilentlyContinue
                if ($cmdletCheck) {
                    Write-Verbose "Resolve-Dns exists, querying records"
                    $mxSplatAlt = @{
                        Query       = $mxSplat.Name
                        QueryType   = $mxSplat.Type
                        NameServer  = $mxSplat.Server
                        ErrorAction = $mxSplat.ErrorAction
                    }
                    $answers = (Resolve-Dns @mxSplatAlt).Answers | Where-Object { $_.RecordType -eq "MX" }
                    $mxRecords = $answers | ForEach-Object {
                        [PSCustomObject]@{
                            Name         = $_.DomainName
                            NameExchange = $_.Exchange
                            Type         = $_.RecordType
                            TTL          = $_.TimeToLive
                            Preference   = $_.Preference
                        }
                    }
                } else {
                    Write-Verbose "`nFor non-Windows platforms, please install DnsClient-PS module."
                    Write-Verbose "`n    Install-Module DnsClient-PS -Scope CurrentUser`n" -ForegroundColor Yellow
                    return "Missing dependency, Resolve-Dns not available"
                }
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            Write-Verbose $_
            return "Unsupported platform, Resolve-DnsName not available"
        } catch {
            Write-Verbose $_
            return "Failure to obtain record"
        }

        return $mxRecords
    }
}