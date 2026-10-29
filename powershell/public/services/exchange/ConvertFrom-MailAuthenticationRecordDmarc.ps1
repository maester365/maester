function ConvertFrom-MailAuthenticationRecordDmarc {
    <#
    .SYNOPSIS
    Returns structured RFC compliant object for a DMARC record

    .DESCRIPTION
    Adapted from:
    - https://cloudbrothers.info/en/powershell-tip-resolve-spf/
    - https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Modules/Providers/ExportEXOProvider.psm1
    - https://xkln.net/blog/getting-mx-spf-dmarc-dkim-and-smtp-banners-with-powershell/
    - DMARC https://datatracker.ietf.org/doc/html/rfc7489

    ```
    record               : v=DMARC1; p=reject; pct=100; rua=mailto:itex-rua@microsoft.com; ruf=mailto:itex-ruf@microsoft.com; fo=1
    valid                : True
    policy               : reject
    policySubdomain      :
    percentage           : 100
    reportAggregate      : {DMARCRecordUri}
    reportForensic       : {DMARCRecordUri}
    reportFailure        : {1}
    reportFailureFormats : {afrf}
    reportFrequency      : 86400
    alignmentDkim        : r
    alignmentSpf         : r
    version              : DMARC1
    warnings             : {sp: No subdomain policy set, adkim: No DKIM alignment set, defaults to relaxed, aspf: No SPF alignment set, defaults to relaxed, ri: No
    report interval set, defaults to 86400 seconds…}
    ```

    .EXAMPLE
    ConvertFrom-MailAuthenticationRecordDmarc -DomainName "microsoft.com"

    Returns [DMARCRecord] for a valid record, "Failure to obtain record" when no matching record exists, "Invalid DMARC record" when a matching record fails validation, or "DNS lookup unavailable" when DNS resolution fails for another reason

    .LINK
    https://maester.dev/docs/commands/ConvertFrom-MailAuthenticationRecordDmarc
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [OutputType([DMARCRecord], [System.String])]
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

    begin {
        #[DMARCRecordUri]::new("mailto:itex-ruf@microsoft.com")
        class DMARCRecordUri {
            [string]$uri
            [mailaddress]$mailAddress
            [string]$reportSizeLimit

            hidden $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
            hidden $matchUri = "(?'uri'mailto:(?'address'[^,!]*)(?:!(?'size'\d+(?:k|m|g|t)))?)(?:,|$)"

            DMARCRecordUri([string]$uri) {
                $this.uri = $uri
                $match = [regex]::Match($uri, $this.matchUri, $this.option)
                $this.mailAddress = ($match.Groups | Where-Object { $_.Name -eq "address" }).Value
                $this.reportSizeLimit = ($match.Groups | Where-Object { $_.Name -eq "size" }).Value
            }
        }

        #[DMARCRecord]::new("v=DMARC1; p=reject; pct=100; rua=mailto:itex-rua@microsoft.com; ruf=mailto:itex-ruf@microsoft.com; fo=1")
        class DMARCRecord {
            [string]$record
            [bool]$valid
            [ValidateSet("none", "quarantine", "reject")]
            [string]$policy #p
            [string]$policySubdomain #sp
            [ValidateRange(0, 100)]
            [int]$percentage = 100 #pct
            [DMARCRecordUri[]]$reportAggregate #rua
            [DMARCRecordUri[]]$reportForensic #ruf
            [ValidateSet("0", "1", "d", "s")]
            [string[]]$reportFailure #fo
            [string[]]$reportFailureFormats = "afrf" #rf
            [int]$reportFrequency = 86400 #ri
            [ValidateSet("r", "s")]
            [string]$alignmentDkim = "r" #adkim
            [ValidateSet("r", "s")]
            [string]$alignmentSpf = "r" #aspf
            [string]$version = "DMARC1"
            [string[]]$warnings

            hidden $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
            hidden $matchInit = "^v\s*=\s*(?'v'DMARC1)\s*;\s*p\s*=\s*(?'p'none|quarantine|reject)(?:$|\s*;\s*)"
            hidden $matchSp = "sp\s*=\s*(?'sp'none|quarantine|reject)(?:$|\s*;\s*)"
            hidden $matchRua = "rua\s*=\s*(?'rua'[^;]+)(?:$|\s*;\s*)"
            hidden $matchRuf = "ruf\s*=\s*(?'ruf'[^;]+)(?:$|\s*;\s*)"
            hidden $matchUri = "(?'uri'mailto:(?'address'[^,!]*)(?:!(?'size'\d+(?:k|m|g|t)))?)(?:,|$)"
            hidden $matchAdkim = "adkim\s*=\s*(?'adkim'r|s)(?:$|\s*;\s*)"
            hidden $matchAspf = "aspf\s*=\s*(?'aspf'r|s)(?:$|\s*;\s*)"
            hidden $matchRi = "ri\s*=\s*(?'ri'\d+)(?:$|\s*;\s*)"
            hidden $matchFo = "fo\s*=\s*(?'fo'.{1})(?:$|\s*;\s*)"
            hidden $matchOptions = "(?'opt'[^:\s])(?:\s*:|\s*$)"
            hidden $matchRf = "rf\s*=\s*(?'rf'[^;]+)(?:$|\s*;\s*)"
            hidden $matchFormat = "(?'format'[^:\s]*)(?:\s*:|\s*$)"
            hidden $matchPct = "pct\s*=\s*(?'pct'\d{1,3})(?:$|\s*;\s*)"

            DMARCRecord([string]$record) {
                $this.record = $record
                $init = $record -match $this.matchInit
                $this.valid = $init
                if (-not $init) {
                    $this.warnings += "v/p: Record version (v) and policy (p) configuration is not proper"
                }
                $this.version = $Matches["v"]
                $this.policy = $Matches["p"]

                $sp = $record -match $this.matchSp
                if (-not $sp) {
                    $this.warnings += "sp: No subdomain policy set"
                } else {
                    $this.policySubdomain = $Matches["sp"]
                }

                $rua = $record -match $this.matchRua
                if (-not $rua) {
                    $this.warnings += "rua: No aggregate report URI set"
                } else {
                    $uris = [regex]::Matches($Matches["rua"], $this.matchUri, $this.option)
                    foreach ($uri in ($uris.Groups | Where-Object { $_.Name -eq "uri" })) {
                        $this.reportAggregate += [DMARCRecordUri]::new("$uri")
                    }
                    if (($uris.Groups | Where-Object { $_.Name -eq "uri" } | Measure-Object).Count -gt 2) {
                        $this.warnings += "ruf: More than 2 URIs set and may be ignored"
                    }
                }

                $ruf = $record -match $this.matchRuf
                if (-not $ruf) {
                    $this.warnings += "ruf: No forensic report URI set"
                } else {
                    $uris = [regex]::Matches($Matches["ruf"], $this.matchUri, $this.option)
                    foreach ($uri in ($uris.Groups | Where-Object { $_.Name -eq "uri" })) {
                        $this.reportForensic += [DMARCRecordUri]::new("$uri")
                    }
                    if (($uris.Groups | Where-Object { $_.Name -eq "uri" } | Measure-Object).Count -gt 2) {
                        $this.warnings += "ruf: More than 2 URIs set and may be ignored"
                    }
                }

                $adkim = $record -match $this.matchAdkim
                if (-not $adkim) {
                    $this.warnings += "adkim: No DKIM alignment set, defaults to relaxed"
                } else {
                    $this.alignmentDkim = $Matches["adkim"]
                }

                $aspf = $record -match $this.matchAspf
                if (-not $aspf) {
                    $this.warnings += "aspf: No SPF alignment set, defaults to relaxed"
                } else {
                    $this.alignmentSpf = $Matches["aspf"]
                }

                $ri = $record -match $this.matchRi
                if (-not $ri) {
                    $this.warnings += "ri: No report interval set, defaults to 86400 seconds"
                } else {
                    $this.reportFrequency = $Matches["ri"]
                }

                $fo = $record -match $this.matchFo
                if (-not $fo) {
                    $this.reportFailure = "0"
                    $this.warnings += "fo: No failure reporting option specified, default (0) report when all mechanisms fail to pass"
                } elseif ($fo -and -not $ruf) {
                    $this.warnings += "fo: Failure reporting option specified, but no ruf URI set"
                } else {
                    $options = [regex]::Matches($Matches["fo"], $this.matchOptions, $this.option)
                    foreach ($option in ($options.Groups | Where-Object { $_.Name -eq "opt" })) {
                        $this.reportFailure += $option
                    }
                }

                $rf = $record -match $this.matchRf
                if (-not $rf) {
                    $this.warnings += "rf: No failure report format specified, defaults to afrf"
                } else {
                    $formats = [regex]::Matches($Matches["rf"], $this.matchFormat, $this.option)
                    foreach ($format in $formats.Groups | Where-Object { $_.Name -eq "format" }) {
                        switch ($format.Value) {
                            "afrf" {
                                $this.reportFailureFormats += $format.Value
                            }
                            "" {}
                            Default {
                                $this.reportFailureFormats += $format.Value
                                $this.warnings += "rf: Unknown failure report format ($($format.Value)) specified"
                            }
                        }
                    }
                }

                $pct = $record -match $this.matchPct
                if (-not $pct) {
                    $this.warnings += "pct: No percentage of messages specified to apply policy to, defaults to 100"
                } else {
                    $parsedPercentage = [int]$Matches["pct"]
                    if ($parsedPercentage -ge 0 -and $parsedPercentage -le 100) {
                        $this.percentage = $parsedPercentage
                    } else {
                        $this.valid = $false
                        $this.warnings += "pct: Value must be between 0 and 100"
                    }
                }
            }
        }
    }

    process {
        $dmarcPrefix  = "_dmarc."
        $matchRecord  = "^v\s*=\s*(?'v'DMARC1)\s*;\s*p\s*=\s*(?'p'none|quarantine|reject)(?:$|\s*;\s*)"
        $regexOptions = [Text.RegularExpressions.RegexOptions]'IgnoreCase,Multiline'

        $dmarcSplat = @{
            Name         = "$dmarcPrefix$DomainName"
            Type         = "TXT"
            Server       = $DnsServerIpAddress
            NoHostsFile  = $NoHostsFile
            QuickTimeout = $QuickTimeout
            ErrorAction  = "Stop"
        }
        try {
            if ( $isWindows -or $PSVersionTable.PSEdition -eq "Desktop") {
                $dmarcAnswers = Resolve-DnsName @dmarcSplat
            } else {
                $cmdletCheck = Get-Command "Resolve-Dns" -ErrorAction SilentlyContinue
                if ($cmdletCheck) {
                    $dmarcSplatAlt = @{
                        Query       = $dmarcSplat.Name
                        QueryType   = $dmarcSplat.Type
                        NameServer  = $dmarcSplat.Server
                        ErrorAction = $dmarcSplat.ErrorAction
                    }
                    $dmarcAnswers = (Resolve-Dns @dmarcSplatAlt).Answers
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
            if ($_.FullyQualifiedErrorId -match 'DNS_(ERROR_RCODE_NAME_ERROR|INFO_NO_RECORDS)') { return "Failure to obtain record" }
            return "DNS lookup unavailable"
        }

        if ( $isWindows -or $PSVersionTable.PSEdition -eq "Desktop") {
            $dmarcRecordText = ($dmarcAnswers | Where-Object { $_.Type -eq "TXT" } | Where-Object { [regex]::Match($_.Strings, $matchRecord, $regexOptions) }).Strings
        } else {
            $dmarcRecordText = ($dmarcAnswers | Where-Object { $_.RecordType -eq "TXT" } | Where-Object { [regex]::Match($_.Text, $matchRecord, $regexOptions) }).Text
        }
        if (-not $dmarcRecordText) { return "Failure to obtain record" }
        try {
            $dmarcRecord = [DMARCRecord]::new($dmarcRecordText)
        } catch {
            Write-Verbose $_
            return "Invalid DMARC record"
        }
        if (-not $dmarcRecord.valid) { return "Invalid DMARC record" }

        return $dmarcRecord
    }
}
