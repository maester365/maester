<#
.SYNOPSIS
    Returns a list of all IP addresses from an SPF record

.DESCRIPTION
    https://cloudbrothers.info/en/powershell-tip-resolve-spf/

.EXAMPLE
    Resolve-SPFRecord microsoft.com

.LINK
    https://maester.dev/docs/commands/Resolve-SPFRecord
#>
function Resolve-SPFRecord {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [OutputType([spfrecord[]], [System.String])]
    [CmdletBinding()]
    param (
        # Domain Name
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [string]$Name,

        # DNS Server to use
        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
        [string]$Server,

        # If called nested provide a referrer to build valid objects
        [Parameter(Mandatory = $false)]
        [string]$Referrer
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
        # Keep track of number of DNS queries
        # DNS Lookup Limit = 10
        # https://tools.ietf.org/html/rfc7208#section-4.6.4
        # Query DNS Record
        try {
            if ($isWindows -or $PSVersionTable.PSEdition -eq "Desktop") {
                if ($Server) {
                    $DNSRecords = Resolve-DnsName -Server $Server -Name $Name -Type TXT -ErrorAction Stop
                } else {
                    $DNSRecords = Resolve-DnsName -Name $Name -Type TXT -ErrorAction Stop
                }
            } else {
                $cmdletCheck = Get-Command "Resolve-Dns" -ErrorAction SilentlyContinue
                if ($cmdletCheck) {
                    $answers = (Resolve-Dns -NameServer $Server -Query $Name -QueryType TXT).Answers
                    $DNSRecords = $answers | ForEach-Object {
                        [PSCustomObject]@{
                            Name    = $_.DomainName
                            Type    = $_.RecordType
                            TTL     = $_.TimeToLive
                            Strings = $_.Text
                        }
                    }
                } else {
                    Write-Verbose "`nFor non-Windows platforms, please install DnsClient-PS module."
                    Write-Verbose "`n    Install-Module DnsClient-PS -Scope CurrentUser`n"
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
        # Check SPF record
        $SPFRecord = $DNSRecords | Where-Object { $_.Strings -match "^v=spf1" }
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
            $SPFDirectives = $SPFString -split " "

            # Check for a redirect
            if ( $SPFDirectives -match "redirect" ) {
                $RedirectRecord = $SPFDirectives -match "redirect" -replace "redirect="
                Write-Verbose "[REDIRECT]`t$RedirectRecord"
                # Follow the redirect and resolve the redirect
                # Check for SPF records that redirect to themselves, it will lead to an infinite loop => ** explosion **
                if ( $Name -ne $RedirectRecord ) {
                    Resolve-SPFRecord -Name "$RedirectRecord" -Server $Server -Referrer $Name
                } else {
                    return "Self-referencing SPF directive"
                }
            } else {

                # Extract the qualifier
                $Qualifier = switch ( $SPFDirectives -match "^[+-?~]all$" -replace "all" ) {
                    "+" { "pass" }
                    "-" { "fail" }
                    "~" { "softfail" }
                    "?" { "neutral" }
                }

                $ReturnValues = foreach ($SPFDirective in $SPFDirectives) {
                    switch -Regex ($SPFDirective) {
                        "%[{%-_]" {
                            Write-Verbose "[$_]`tMacros are not supported. For more information, see https://tools.ietf.org/html/rfc7208#section-7"
                            Continue
                        }
                        "^exp:.*$" {
                            Write-Verbose "[$_]`tExplanation is not supported. For more information, see https://tools.ietf.org/html/rfc7208#section-6.2"
                            Continue
                        }
                        '^include:.*$' {
                            # Follow the include and resolve the include
                            $IncludeTarget = ( $SPFDirective -replace "^include:" )
                            # Check for SPF records that include themselves, it will lead to an infinite loop => ** explosion **
                            if ( $Name -ne $IncludeTarget ) {
                                Resolve-SPFRecord -Name $IncludeTarget -Server $Server -Referrer $Name
                            } else {
                                return "Self-referencing SPF directive"
                            }
                        }
                        '^ip[46]:.*$' {
                            Write-Verbose "[IP]`tSPF entry: $SPFDirective"
                            $SPFObject = [SPFRecord]::New( ($SPFDirective -replace "^ip[46]:"), $Name, $Qualifier)
                            if ( $PSBoundParameters.ContainsKey('Referrer') ) {
                                $SPFObject.Referrer = $Referrer
                                $SPFObject.Include = $true
                            }
                            $SPFObject
                        }
                        '^a:.*$' {
                            Write-Verbose "[A]`tSPF entry: $SPFDirective"
                            if ( $isWindows -or $PSVersionTable.PSEdition -eq "Desktop" ) {
                                $DNSRecords = Resolve-DnsName -Server $Server -Name $Name -Type A
                            } else {
                                $answers = (Resolve-Dns -NameServer $Server -Query $Name -QueryType A).Answers
                                $DNSRecords = $answers | ForEach-Object {
                                    [PSCustomObject]@{
                                        Name       = $_.DomainName
                                        Type       = $_.RecordType
                                        TTL        = $_.TimeToLive
                                        DataLength = $_.RawDataLength
                                        Section    = "Answer"
                                        IPAddress  = $_.Address
                                    }
                                }
                            }
                            # Check SPF record
                            foreach ($IPAddress in ($DNSRecords.IPAddress) ) {
                                $SPFObject = [SPFRecord]::New( $IPAddress, ($SPFDirective -replace "^a:"), $Qualifier)
                                if ( $PSBoundParameters.ContainsKey('Referrer') ) {
                                    $SPFObject.Referrer = $Referrer
                                    $SPFObject.Include = $true
                                }
                                $SPFObject
                            }
                        }
                        '^mx:.*$' {
                            Write-Verbose "[MX]`tSPF entry: $SPFDirective"
                            if ( $isWindows -or $PSVersionTable.PSEdition -eq "Desktop" ) {
                                $DNSRecords = Resolve-DnsName -Server $Server -Name $Name -Type MX
                            } else {
                                $answers = (Resolve-Dns -NameServer $Server -Query $Name -QueryType MX).Answers
                                $DNSRecords = $answers | ForEach-Object {
                                    [PSCustomObject]@{
                                        Name         = $_.DomainName
                                        Type         = $_.RecordType
                                        TTL          = $_.TimeToLive
                                        NameExchange = $_.Exchange
                                        Preference   = $_.Preference
                                    }
                                }
                            }
                            foreach ($MXRecords in ($DNSRecords.NameExchange) ) {
                                # Check SPF record
                                if ( $isWindows -or $PSVersionTable.PSEdition -eq "Desktop" ) {
                                    $DNSRecords = Resolve-DnsName -Server $Server -Name $MXRecords -Type A
                                } else {
                                    $answers = (Resolve-Dns -NameServer $Server -Query $Name -QueryType A).Answers
                                    $DNSRecords = $answers | ForEach-Object {
                                        [PSCustomObject]@{
                                            Name       = $_.DomainName
                                            Type       = $_.RecordType
                                            TTL        = $_.TimeToLive
                                            DataLength = $_.RawDataLength
                                            Section    = "Answer"
                                            IPAddress  = $_.Address
                                        }
                                    }
                                }
                                foreach ($IPAddress in ($DNSRecords.IPAddress) ) {
                                    $SPFObject = [SPFRecord]::New( $IPAddress, ($SPFDirective -replace "^mx:"), $Qualifier)
                                    if ( $PSBoundParameters.ContainsKey('Referrer') ) {
                                        $SPFObject.Referrer = $Referrer
                                        $SPFObject.Include = $true
                                    }
                                    $SPFObject
                                }
                            }
                        }
                        Default {
                            Write-Verbose "[$_]`t Unknown directive"
                        }
                    }
                }

                $DNSQuerySum = $ReturnValues.Referrer + $ReturnValues.SPFSourceDomain | Select-Object -Unique | Where-Object {$_ -ne $Name} | Measure-Object | Select-Object -ExpandProperty Count
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

    end {

    }
}
