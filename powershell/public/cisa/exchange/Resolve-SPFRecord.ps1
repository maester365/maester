function Resolve-SPFRecord {
    <#
    .SYNOPSIS
        Returns a list of all IP addresses from an SPF record.

    .DESCRIPTION
        A function to resolve and parse SPF records for a given domain name.

        Supported SPF directives and functions include:
        - mx
        - a
        - ip4 und ip6
        - redirect
        - Warning for too many include entries

        Not supported:
        - explanation
        - macros

    .PARAMETER Name
        The domain name to resolve the SPF record for.

    .PARAMETER Server
        The DNS server to use for the query. If not specified, the system's default DNS server will be used.

    .EXAMPLE
        Resolve-SPFRecord microsoft.com

        Resolves the SPF record for the domain "microsoft.com" using the default DNS server.

    .EXAMPLE
        Resolve-SPFRecord -Name microsoft.com -Server 1.1.1.1

        Resolves the SPF record for the domain "microsoft.com" using the specified DNS server.

    .LINK
        https://maester.dev/docs/commands/Resolve-SPFRecord

    .LINK
        https://cloudbrothers.info/en/powershell-tip-resolve-spf/
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [OutputType([SPFRecord[]], [System.String])]
    [CmdletBinding()]
    param (
        # Domain name to resolve SPF record for.
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        # DNS server to use for the query.
        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        # Provide a referrer to build valid objects during recursive calls of the function.
        [Parameter(Mandatory = $false, DontShow = $true)]
        [string]$Referrer,

        # Track visited domains to prevent circular references during recursive calls of the function.
        [Parameter(Mandatory = $false, DontShow = $true)]
        [string[]]$Visited = @()
    )

    begin {
        class SPFRecord {
            [string] $SPFSourceDomain
            [string] $IPAddress
            [string] $Referrer
            [string] $Qualifier
            [bool] $Include

            # Constructor: Creates a new SPFRecord object, with a specified IPAddress
            SPFRecord ([string] $IPAddress) {
                $this.IPAddress = $IPAddress
            }

            # Constructor: Creates a new SPFRecord object, with a specified IPAddress and DNSName
            SPFRecord ([string] $IPAddress, [String] $DNSName) {
                $this.IPAddress = $IPAddress
                $this.SPFSourceDomain = $DNSName
            }

            # Constructor: Creates a new SPFRecord object, with a specified IPAddress and DNSName and
            SPFRecord ([string] $IPAddress, [String] $DNSName, [String] $Qualifier) {
                $this.IPAddress = $IPAddress
                $this.SPFSourceDomain = $DNSName
                $this.Qualifier = $Qualifier
            }
        }
    }

    process {
        # Add current domain to visited list for circular reference detection
        $Visited = $Visited + $Name

        # Keep track of number of DNS queries
        # DNS Lookup Limit = 10
        # https://tools.ietf.org/html/rfc7208#section-4.6.4
        # Query DNS Record
        try {
            if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
                if ($Server) {
                    $DNSRecords = Resolve-DnsName -Server $Server -Name $Name -Type TXT -ErrorAction Stop
                } else {
                    $DNSRecords = Resolve-DnsName -Name $Name -Type TXT -ErrorAction Stop
                }
            } else {
                $cmdletCheck = Get-Command 'Resolve-Dns' -ErrorAction SilentlyContinue
                if ($cmdletCheck) {
                    $dnsParams = @{
                        Query     = $Name
                        QueryType = 'TXT'
                    }
                    if ($Server) {
                        $dnsParams['NameServer'] = $Server
                    }
                    $answers = (Resolve-Dns @dnsParams).Answers
                    $DNSRecords = $answers | ForEach-Object {
                        [PSCustomObject]@{
                            Name    = $_.DomainName
                            Type    = $_.RecordType
                            TTL     = $_.TimeToLive
                            Strings = $_.Text
                        }
                    }
                } else {
                    Write-Error 'For non-Windows platforms, please install DnsClient-PS module: Install-Module DnsClient-PS -Scope CurrentUser'
                    return
                }
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            Write-Error "Unsupported platform: $_"
            return
        } catch {
            Write-Error "Failed to obtain DNS record for ${Name}: $_"
            return
        }
        # Check SPF record
        $SPFRecord = $DNSRecords | Where-Object { $_.Strings -match '^v=spf1' }
        # Validate SPF record
        $SPFCount = ($SPFRecord | Measure-Object).Count

        if ( $SPFCount -eq 0) {
            # If there is no error show an error
            Write-Verbose "No SPF record found for `"$Name`""
        } elseif ( $SPFCount -ge 2 ) {
            # Multiple DNS Records are not allowed
            # https://tools.ietf.org/html/rfc7208#section-3.2
            Write-Verbose "There is more than one SPF for domain `"$Name`""
        } else {
            # Multiple Strings in a Single DNS Record
            # https://tools.ietf.org/html/rfc7208#section-3.3
            $SPFString = $SPFRecord.Strings -join ''
            # Split the directives at the whitespace
            $SPFDirectives = $SPFString -split ' '

            # Check for a redirect
            if ( $SPFDirectives -match 'redirect' ) {
                $RedirectRecord = $SPFDirectives -match 'redirect' -replace 'redirect='
                Write-Verbose "[REDIRECT]`t$RedirectRecord"
                # Follow the redirect and resolve the redirect
                # Check for circular SPF references to prevent infinite loops
                if ( $RedirectRecord -eq $Name ) {
                    Write-Warning "Self-referencing SPF redirect detected for $Name"
                    return
                } elseif ( $RedirectRecord -notin $Visited ) {
                    if ($Server) {
                        Resolve-SPFRecord -Name "$RedirectRecord" -Server $Server -Referrer $Name -Visited $Visited
                    } else {
                        Resolve-SPFRecord -Name "$RedirectRecord" -Referrer $Name -Visited $Visited
                    }
                } else {
                    Write-Warning "Circular SPF reference detected: $Name -> $RedirectRecord"
                    return
                }
            } else {

                # Extract the qualifier
                $Qualifier = switch ( $SPFDirectives -match '^[+-?~]all$' -replace 'all' ) {
                    '+' { 'pass' }
                    '-' { 'fail' }
                    '~' { 'softfail' }
                    '?' { 'neutral' }
                }

                $ReturnValues = foreach ($SPFDirective in $SPFDirectives) {
                    switch -Regex ($SPFDirective) {
                        '%[{%-_]' {
                            Write-Verbose "[$_]`tMacros are not supported. For more information, see https://tools.ietf.org/html/rfc7208#section-7"
                            continue
                        }
                        '^exp:.*$' {
                            Write-Verbose "[$_]`tExplanation is not supported. For more information, see https://tools.ietf.org/html/rfc7208#section-6.2"
                            continue
                        }
                        '^include:.*$' {
                            # Follow the include and resolve the include
                            $IncludeTarget = ( $SPFDirective -replace '^include:' )
                            # Check for circular SPF references to prevent infinite loops
                            if ( $IncludeTarget -eq $Name ) {
                                Write-Warning "Self-referencing SPF include detected for $Name"
                                continue
                            } elseif ( $IncludeTarget -notin $Visited ) {
                                if ($Server) {
                                    Resolve-SPFRecord -Name $IncludeTarget -Server $Server -Referrer $Name -Visited $Visited
                                } else {
                                    Resolve-SPFRecord -Name $IncludeTarget -Referrer $Name -Visited $Visited
                                }
                            } else {
                                Write-Warning "Circular SPF reference detected: $Name includes $IncludeTarget"
                                continue
                            }
                        }
                        '^ip[46]:.*$' {
                            Write-Verbose "[IP]`tSPF entry: $SPFDirective"
                            $SPFObject = [SPFRecord]::New( ($SPFDirective -replace '^ip[46]:'), $Name, $Qualifier)
                            if ( $PSBoundParameters.ContainsKey('Referrer') ) {
                                $SPFObject.Referrer = $Referrer
                                $SPFObject.Include = $true
                            }
                            $SPFObject
                        }
                        '^a:.*$' {
                            Write-Verbose "[A]`tSPF entry: $SPFDirective"
                            # Extract the domain from the directive (e.g., "a:sub.example.com" -> "sub.example.com")
                            $aDomain = $SPFDirective -replace '^a:'
                            if ([string]::IsNullOrEmpty($aDomain)) {
                                $aDomain = $Name  # If no domain specified, use current domain
                            }

                            if ( $IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop' ) {
                                if ($Server) {
                                    $DNSRecords = Resolve-DnsName -Server $Server -Name $aDomain -Type A -ErrorAction SilentlyContinue
                                } else {
                                    $DNSRecords = Resolve-DnsName -Name $aDomain -Type A -ErrorAction SilentlyContinue
                                }
                            } else {
                                $dnsParams = @{
                                    Query     = $aDomain
                                    QueryType = 'A'
                                }
                                if ($Server) {
                                    $dnsParams['NameServer'] = $Server
                                }
                                $answers = (Resolve-Dns @dnsParams -ErrorAction SilentlyContinue).Answers
                                $DNSRecords = $answers | ForEach-Object {
                                    [PSCustomObject]@{
                                        Name       = $_.DomainName
                                        Type       = $_.RecordType
                                        TTL        = $_.TimeToLive
                                        DataLength = $_.RawDataLength
                                        Section    = 'Answer'
                                        IPAddress  = $_.Address
                                    }
                                }
                            }
                            # Check SPF record
                            foreach ($IPAddress in ($DNSRecords.IPAddress) ) {
                                $SPFObject = [SPFRecord]::New( $IPAddress, $aDomain, $Qualifier)
                                if ( $PSBoundParameters.ContainsKey('Referrer') ) {
                                    $SPFObject.Referrer = $Referrer
                                    $SPFObject.Include = $true
                                }
                                $SPFObject
                            }
                        }
                        '^mx:.*$' {
                            Write-Verbose "[MX]`tSPF entry: $SPFDirective"
                            # Extract the domain from the directive (e.g., "mx:mail.example.com" -> "mail.example.com")
                            $mxDomain = $SPFDirective -replace '^mx:'
                            if ([string]::IsNullOrEmpty($mxDomain)) {
                                $mxDomain = $Name  # If no domain specified, use current domain
                            }

                            if ( $IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop' ) {
                                if ($Server) {
                                    $MXDNSRecords = Resolve-DnsName -Server $Server -Name $mxDomain -Type MX -ErrorAction SilentlyContinue
                                } else {
                                    $MXDNSRecords = Resolve-DnsName -Name $mxDomain -Type MX -ErrorAction SilentlyContinue
                                }
                            } else {
                                $dnsParams = @{
                                    Query     = $mxDomain
                                    QueryType = 'MX'
                                }
                                if ($Server) {
                                    $dnsParams['NameServer'] = $Server
                                }
                                $answers = (Resolve-Dns @dnsParams -ErrorAction SilentlyContinue).Answers
                                $MXDNSRecords = $answers | ForEach-Object {
                                    [PSCustomObject]@{
                                        Name         = $_.DomainName
                                        Type         = $_.RecordType
                                        TTL          = $_.TimeToLive
                                        NameExchange = $_.Exchange
                                        Preference   = $_.Preference
                                    }
                                }
                            }
                            foreach ($MXRecord in ($MXDNSRecords.NameExchange) ) {
                                # Resolve A records for each MX host
                                if ( $IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop' ) {
                                    if ($Server) {
                                        $ADNSRecords = Resolve-DnsName -Server $Server -Name $MXRecord -Type A -ErrorAction SilentlyContinue
                                    } else {
                                        $ADNSRecords = Resolve-DnsName -Name $MXRecord -Type A -ErrorAction SilentlyContinue
                                    }
                                } else {
                                    $dnsParams = @{
                                        Query     = $MXRecord
                                        QueryType = 'A'
                                    }
                                    if ($Server) {
                                        $dnsParams['NameServer'] = $Server
                                    }
                                    $answers = (Resolve-Dns @dnsParams -ErrorAction SilentlyContinue).Answers
                                    $ADNSRecords = $answers | ForEach-Object {
                                        [PSCustomObject]@{
                                            Name       = $_.DomainName
                                            Type       = $_.RecordType
                                            TTL        = $_.TimeToLive
                                            DataLength = $_.RawDataLength
                                            Section    = 'Answer'
                                            IPAddress  = $_.Address
                                        }
                                    }
                                }
                                foreach ($IPAddress in ($ADNSRecords.IPAddress) ) {
                                    $SPFObject = [SPFRecord]::New( $IPAddress, $mxDomain, $Qualifier)
                                    if ( $PSBoundParameters.ContainsKey('Referrer') ) {
                                        $SPFObject.Referrer = $Referrer
                                        $SPFObject.Include = $true
                                    }
                                    $SPFObject
                                }
                            }
                        }
                        default {
                            Write-Verbose "[$_]`t Unknown directive"
                        }
                    }
                }

                $DNSQuerySum = $ReturnValues.Referrer + $ReturnValues.SPFSourceDomain | Select-Object -Unique | Where-Object { $_ -ne $Name } | Measure-Object | Select-Object -ExpandProperty Count
                if ( $DNSQuerySum -gt 6) {
                    Write-Verbose "Watch your includes!`nThe maximum number of DNS queries is 10 and you have already $DNSQuerySum.`nCheck https://tools.ietf.org/html/rfc7208#section-4.6.4"
                }
                if ( $DNSQuerySum -gt 10) {
                    Write-Verbose "Too many DNS queries made ($DNSQuerySum).`nMust not exceed 10 DNS queries.`nCheck https://tools.ietf.org/html/rfc7208#section-4.6.4"
                }

                return $ReturnValues
            }
        }
    }
}
