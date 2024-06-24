<#
.SYNOPSIS
    Checks ...

.DESCRIPTION

    Adapted from:
    - https://cloudbrothers.info/en/powershell-tip-resolve-spf/
    - https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Modules/Providers/ExportEXOProvider.psm1
    - https://xkln.net/blog/getting-mx-spf-dmarc-dkim-and-smtp-banners-with-powershell/
    - SPF https://datatracker.ietf.org/doc/html/rfc7208
    - DMARC https://datatracker.ietf.org/doc/html/rfc7489

.EXAMPLE
    Test-MtCisaAutoExternalForwarding

    Returns true if no domain is enabled for auto forwarding
#>

Function Get-MailAuthenticationRecords {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DomainName,

        [ipaddress]$DnsServerIpAddress = "1.1.1.1",

        [string]$DkimSelector = "selector1",

        [ValidateSetAttribute("All","DKIM","DMARC","MX","SPF")]
        [string[]]$Records = "All"
    )

    begin {
        if($Records -contains "All"){
            $all = $dkim = $dmarc = $mx = $spf = $true
        }else{
            foreach($record in $Records){
                Set-Variable -Name $record -Value $true
            }
        }

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
            [ValidateSet("+","-","~","?")]
            [string]$qualifier #qual
            [ValidateSet("all","include","a","mx","ptr","ip4","ip6","exists")]
            [string]$mechanism #mech
            [string]$mechanismTarget #mechTarget
            [string]$mechanismTargetCidr #cidr
            [ValidateSet("redirect","exp")]
            [string]$modifier #mod
            [string]$modifierTarget #modTarget

            hidden $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
            hidden $matchTerms = "\s*(?'term'(?'directive'(?'qual'\+|-|~|\?)?(?'mech'all|include|a|mx|ptr|ip4|ip6|exists)(?::?(?'mechTarget'[^\s]+?(?'cidr'\/[^\s]+)?))?)(?:\s|$)|(?'mod'redirect|exp)(?:=(?'modTarget'[^\s]+))(?:\s|$))"

            SPFRecordTerm([string]$term){
                $this.term = $term
                $match = [regex]::Match($term,$this.matchTerms,$this.option)
                $this.directive = ($match.Groups|Where-Object{$_.Name -eq "directive"}).Value
                $this.qualifier = ($match.Groups|Where-Object{$_.Name -eq "qual"}).Value
                $this.mechanism = ($match.Groups|Where-Object{$_.Name -eq "mech"}).Value
                $this.mechanismTarget = ($match.Groups|Where-Object{$_.Name -eq "mechTarget"}).Value
                $this.mechanismTargetCidr = ($match.Groups|Where-Object{$_.Name -eq "cidr"}).Value
                $this.modifier = ($match.Groups|Where-Object{$_.Name -eq "mod"}).Value
                $this.modifierTarget = ($match.Groups|Where-Object{$_.Name -eq "modTarget"}).Value
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

            SPFRecord([string]$inputRecord){
                $this.record = $inputRecord
                $match = [regex]::Matches($inputRecord,$this.matchRecord,$this.option)
                if(-not $match){
                    $this.warnings += "v: Record does not match spf1 version format"
                    break
                }
                if(($match|Measure-Object).Count -gt 1){
                    $this.warnings += "v: Multiple records match spf1 version format"
                    break
                }
                $recordTerms = [regex]::Matches($inputRecord,$this.matchTerms,$this.option)
                foreach($term in ($recordTerms.Groups|Where-Object{$_.Name -eq "term"})){
                    $this.terms += [SPFRecordTerm]::new($term.Value)
                }
            }
        }

        #[DMARCRecordUri]::new("mailto:itex-ruf@microsoft.com")
        class DMARCRecordUri {
            [string]$uri
            [mailaddress]$mailAddress
            [string]$reportSizeLimit

            hidden $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
            hidden $matchUri = "(?'uri'mailto:(?'address'[^,!]*)(?:!(?'size'\d+(?:k|m|g|t)))?)(?:,|$)"

            DMARCRecordUri([string]$uri){
                $this.uri = $uri
                $match = [regex]::Match($uri,$this.matchUri,$this.option)
                $this.mailAddress = ($match.Groups|Where-Object{$_.Name -eq "address"}).Value
                $this.reportSizeLimit = ($match.Groups|Where-Object{$_.Name -eq "size"}).Value
            }
        }

        #[DMARCRecord]::new("v=DMARC1; p=reject; pct=100; rua=mailto:itex-rua@microsoft.com; ruf=mailto:itex-ruf@microsoft.com; fo=1")
        class DMARCRecord {
            [string]$record
            [bool]$valid
            [ValidateSet("none","quarantine","reject")]
            [string]$policy #p
            [string]$policySubdomain #sp
            [ValidateRange(0,100)]
            [int]$percentage = 100 #pct
            [DMARCRecordUri[]]$reportAggregate #rua
            [DMARCRecordUri[]]$reportForensic #ruf
            [ValidateSet("0","1","d","s")]
            [string[]]$reportFailure #fo
            [string[]]$reportFailureFormats = "afrf" #rf
            [int]$reportFrequency = 86400 #ri
            [ValidateSet("r","s")]
            [string]$alignmentDkim = "r" #adkim
            [ValidateSet("r","s")]
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

            DMARCRecord([string]$record){
                $this.record = $record
                $init = $record -match $this.matchInit
                $this.valid = $init
                if(-not $init){
                    $this.warnings += "v/p: Record version (v) and policy (p) configuration is not proper"
                    exit
                }
                $this.version = $Matches["v"]
                $this.policy = $Matches["p"]

                $sp = $record -match $this.matchSp
                if(-not $sp){
                    $this.warnings += "sp: No subdomain policy set"
                }else{
                    $this.policySubdomain = $Matches["sp"]
                }

                $rua = $record -match $this.matchRua
                if(-not $rua){
                    $this.warnings += "rua: No aggregate report URI set"
                }else{
                    $uris = [regex]::Matches($Matches["rua"],$this.matchUri,$this.option)
                    foreach($uri in ($uris.Groups|Where-Object{$_.Name -eq "uri"})){
                        $this.reportAggregate += [DMARCRecordUri]::new("$uri")
                    }
                    if(($uris.Groups|Where-Object{$_.Name -eq "uri"}|Measure-Object).Count -gt 2){
                        $this.warnings += "ruf: More than 2 URIs set and may be ignored"
                    }
                }

                $ruf = $record -match $this.matchRuf
                if(-not $ruf){
                    $this.warnings += "ruf: No forensic report URI set"
                }else{
                    $uris = [regex]::Matches($Matches["ruf"],$this.matchUri,$this.option)
                    foreach($uri in ($uris.Groups|Where-Object{$_.Name -eq "uri"})){
                        $this.reportForensic += [DMARCRecordUri]::new("$uri")
                    }
                    if(($uris.Groups|Where-Object{$_.Name -eq "uri"}|Measure-Object).Count -gt 2){
                        $this.warnings += "ruf: More than 2 URIs set and may be ignored"
                    }
                }

                $adkim = $record -match $this.matchAdkim
                if(-not $adkim){
                    $this.warnings += "adkim: No DKIM alignment set, defaults to relaxed"
                }else{
                    $this.alignmentDkim = $Matches["adkim"]
                }

                $aspf = $record -match $this.matchAspf
                if(-not $aspf){
                    $this.warnings += "aspf: No SPF alignment set, defaults to relaxed"
                }else{
                    $this.alignmentSpf = $Matches["aspf"]
                }

                $ri = $record -match $this.matchRi
                if(-not $ri){
                    $this.warnings += "ri: No report interval set, defaults to 86400 seconds"
                }else{
                    $this.ri = $Matches["ri"]
                }

                $fo = $record -match $this.matchFo
                if(-not $fo){
                    $this.reportFailure = "0"
                    $this.warnings += "fo: No failure reporting option specified, default (0) report when all mechanisms fail to pass"
                }elseif($fo -and -not $ruf){
                    $this.warnings += "fo: Failure reporting option specified, but no ruf URI set"
                }else{
                    $options = [regex]::Matches($Matches["fo"],$this.matchOptions,$this.option)
                    foreach($option in ($options.Groups|Where-Object{$_.Name -eq "opt"})){
                        $this.reportFailure += $option
                    }
                }

                $rf = $record -match $this.matchRf
                if(-not $rf){
                    $this.warnings += "rf: No failure report format specified, defaults to afrf"
                }else{
                    $formats = [regex]::Matches($Matches["rf"],$this.matchFormat,$this.option)
                    foreach($format in $formats.Groups|Where-Object{$_.Name -eq "format"}){
                        switch ($format.Value) {
                            "afrf" {
                                $this.reportFailureFormats += $format.Value
                            }
                            "" {}
                            Default {
                                $this.reportFailureFormats += $format.Value
                                $this.warnings += "rf: Unkown failure report format ($($format.Value)) specified"
                            }
                        }
                    }
                }

                $pct = $record -match $this.matchPct
                if(-not $pct){
                    $this.warnings += "pct: No percentage of messages specified to apply policy to, defaults to 100"
                }else{
                    $this.percentage = $Matches["pct"]
                }
            }
        }

        #TODO, add additional regexs for additional options

        class DKIMRecord {
            [string]$record
            [string]$keyType = "rsa" #k
            [string[]]$hash = @("sha1","sha256") #h
            [string]$notes #n
            [string]$publicKey #p
            [bool]$validBase64
            [string[]]$services = "*" #s (*,email)
            [string[]]$flags #t (y,s)
            [string[]]$warnings

            hidden $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
            hidden $matchRecord = "^v\s*=\s*(?'v'DKIM1)\s*;\s*"
            hidden $matchKeyType = "k\s*=\s*(?'k'[^;]+)\s*;\s*"
            hidden $matchPublicKey = "p\s*=\s*(?'p'[^;]+)\s*;\s*"

            DKIMRecord([string]$record){
                $this.record = $record
                $match = $record -match $this.matchRecord
                if(-not $match){
                    $this.warnings = "v: Record does not match version format"
                    break
                }
                $p = [regex]::Match($record,$this.matchPublicKey,$this.option)
                $this.publicKey = ($p.Groups|Where-Object{$_.Name -eq "p"}).Value
                $bytes = [System.Convert]::FromBase64String(($p.Groups|Where-Object{$_.Name -eq "p"}).Value)
                $this.validBase64 = $null -ne $bytes
            }
        }
    }

    process {

    }
}