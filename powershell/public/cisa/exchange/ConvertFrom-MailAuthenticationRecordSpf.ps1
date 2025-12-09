<#
.SYNOPSIS
    Returns a structured RFC compliant object for the supplied SPF record

.DESCRIPTION
    Adapted from:
    - https://cloudbrothers.info/en/powershell-tip-resolve-spf/
    - https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Modules/Providers/ExportEXOProvider.psm1
    - https://xkln.net/blog/getting-mx-spf-dmarc-dkim-and-smtp-banners-with-powershell/
    - SPF https://datatracker.ietf.org/doc/html/rfc7208

    ```
    record   : v=spf1 include:_spf-a.microsoft.com include:_spf-b.microsoft.com include:_spf-c.microsoft.com include:_spf-ssg-a.msft.net include:spf-a.hotmail.com
            include:_spf1-meo.microsoft.com -all
    terms    : {SPFRecordTerm, SPFRecordTerm, SPFRecordTerm, SPFRecordTerm…}
    warnings :
    ```

.EXAMPLE
    ConvertFrom-MailAuthenticationRecordSpf -DomainName "microsoft.com"

    Returns [SPFRecord] object or "Failure to obtain record"

.LINK
    https://maester.dev/docs/commands/ConvertFrom-MailAuthenticationRecordSpf
#>
function ConvertFrom-MailAuthenticationRecordSpf {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [OutputType([SPFRecord], [System.String])]
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
        #todo, check that all is always at end,
        ###check that ptr isn't used,
        ###check for repeat modifiers,
        ###check for all and redirect,
        ###check for unrecognized modifiers,
        ###recommend exp if not found #https://datatracker.ietf.org/doc/html/rfc7208#section-6.2,
        ###check for macros #https://datatracker.ietf.org/doc/html/rfc7208#section-7,
        ###check for 10* include, a, mx, ptr, exists
        #[SPFRecordTerm]::new("include:_spf-a.microsoft.com")
        class SPFRecordTerm {
            [string]$term #term
            [string]$directive #directive
            [ValidateSet("+", "-", "~", "?", "")]
            [string]$qualifier #qual
            [ValidateSet("all", "include", "a", "mx", "ptr", "ip4", "ip6", "exists", "")]
            [string]$mechanism #mech
            [string]$mechanismTarget #mechTarget
            [string]$mechanismTargetCidr #cidr
            [ValidateSet("redirect", "exp", "")]
            [string]$modifier #mod
            [string]$modifierTarget #modTarget

            hidden $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
            hidden $matchTerms = "\s*(?'term'(?'directive'(?'qual'\+|-|~|\?)?(?'mech'all|include|a|mx|ptr|ip4|ip6|exists)(?::?(?'mechTarget'[^\s]+?(?'cidr'\/[^\s]+)?))?)(?:\s|$)|(?'mod'redirect|exp)(?:=(?'modTarget'[^\s]+))(?:\s|$))"

            SPFRecordTerm([string]$term) {
                $this.term = $term
                $match = [regex]::Match($term, $this.matchTerms, $this.option)
                $this.directive = ($match.Groups | Where-Object { $_.Name -eq "directive" }).Value
                $qVal = ($match.Groups | Where-Object { $_.Name -eq "qual" }).Value
                if ($qVal -eq "") {
                    $q = "?"
                } else {
                    $q = $qVal
                }
                $this.qualifier = $q
                $this.mechanism = ($match.Groups | Where-Object { $_.Name -eq "mech" }).Value
                $this.mechanismTarget = ($match.Groups | Where-Object { $_.Name -eq "mechTarget" }).Value
                $this.mechanismTargetCidr = ($match.Groups | Where-Object { $_.Name -eq "cidr" }).Value
                $this.modifier = ($match.Groups | Where-Object { $_.Name -eq "mod" }).Value
                $this.modifierTarget = ($match.Groups | Where-Object { $_.Name -eq "modTarget" }).Value
            }
        }

        #[spfrecord]::new("v=spf1 include:_spf-a.microsoft.com include:_spf-b.microsoft.com include:_spf-c.microsoft.com include:_spf-ssg-a.msft.net include:spf-a.hotmail.com include:_spf1-meo.microsoft.com -all")
        class SPFRecord {
            [string]$record
            [SPFRecordTerm[]]$terms
            [string]$warnings


            hidden $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase# -bor [Text.RegularExpressions.RegexOptions]::Singleline
            hidden $matchRecord = "^v=spf1 .*$"
            #https://datatracker.ietf.org/doc/html/rfc7208#section-12
            hidden $matchTerms = "\s*(?'term'(?'directive'(?'qual'\+|-|~|\?)?(?'mech'all|include|a|mx|ptr|ip4|ip6|exists)(?::?(?'mechTarget'[^\s]+?(?'cidr'\/[^\s]+)?))?)(?:\s|$)|(?'mod'redirect|exp)(?:=(?'modTarget'[^\s]+))(?:\s|$))"

            SPFRecord([string]$inputRecord) {
                $this.record = $inputRecord
                $match = [regex]::Matches($inputRecord, $this.matchRecord, $this.option)
                if (-not $match) {
                    $this.warnings += "v: Record does not match spf1 version format"
                    break
                }
                if (($match | Measure-Object).Count -gt 1) {
                    $this.warnings += "v: Multiple records match spf1 version format"
                    break
                }
                $recordTerms = [regex]::Matches($inputRecord, $this.matchTerms, $this.option)
                foreach ($term in ($recordTerms.Groups | Where-Object { $_.Name -eq "term" })) {
                    $this.terms += [SPFRecordTerm]::new($term.Value)
                }
            }
        }
    }

    process {
        $matchRecord = "^v=spf1 .*$"

        $spfSplat = @{
            Name         = $DomainName
            Type         = "TXT"
            Server       = $DnsServerIpAddress
            NoHostsFile  = $NoHostsFile
            QuickTimeout = $QuickTimeout
            ErrorAction  = "Stop"
        }
        try {
            if ( $isWindows -or $PSVersionTable.PSEdition -eq "Desktop" ) {
                $spfRecord = [SPFRecord]::new((Resolve-DnsName @spfSplat | `
                            Where-Object { $_.Type -eq "TXT" } | `
                            Where-Object { $_.Strings -imatch $matchRecord }).Strings)
            } else {
                $cmdletCheck = Get-Command "Resolve-Dns" -ErrorAction SilentlyContinue
                if ($cmdletCheck) {
                    $spfSplatAlt = @{
                        Query       = $spfSplat.Name
                        QueryType   = $spfSplat.Type
                        NameServer  = $spfSplat.Server
                        ErrorAction = $spfSplat.ErrorAction
                    }
                    $spfRecord = [SPFRecord]::new(((Resolve-Dns @spfSplatAlt).Answers | `
                                Where-Object { $_.RecordType -eq "TXT" } | `
                                Where-Object { $_.Text -imatch $matchRecord }).Text)
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

        return $spfRecord
    }
}