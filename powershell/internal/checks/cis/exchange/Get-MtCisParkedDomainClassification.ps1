function Get-MtCisParkedDomainClassification {
    <#
    .SYNOPSIS
    Classifies an accepted domain using DNS evidence for the CIS email-authentication checks.

    .DESCRIPTION
    Sending requires a positive SPF mechanism, a DKIM selector record, or an Exchange DKIM signing
    configuration. NotSending requires a single SPF record with only a non-authorizing all
    mechanism and no known DKIM selector records or Exchange signing configuration. Parked
    additionally requires no MX record (or a null MX) and no address or CNAME record at the domain
    apex. Incomplete or conflicting evidence is Unknown and must not receive the parked-domain
    audit exception.

    .PARAMETER DomainName
    The accepted domain to classify.

    .PARAMETER DkimSigningConfigs
    Exchange DKIM signing configurations already retrieved by the calling test.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$DomainName,

        [object[]]$DkimSigningConfigs = @(),

        [string[]]$ParkedDomains = @()
    )

    $lookups = [ordered]@{
        SPF   = Resolve-MtDnsRecord -Name $DomainName -Type TXT
        MX    = Resolve-MtDnsRecord -Name $DomainName -Type MX
        A     = Resolve-MtDnsRecord -Name $DomainName -Type A
        AAAA  = Resolve-MtDnsRecord -Name $DomainName -Type AAAA
        CNAME = Resolve-MtDnsRecord -Name $DomainName -Type CNAME
    }
    foreach ($selector in 'selector1', 'selector2') {
        foreach ($type in 'CNAME', 'TXT') {
            $lookupName = "$selector._domainkey.$DomainName"
            $lookups["DKIM:$selector`:$type"] = Resolve-MtDnsRecord -Name $lookupName -Type $type
        }
    }

    $spfAnswers = @($lookups.SPF.Answers | ForEach-Object { $_.Value } | Where-Object { $_ -match '^\s*v=spf1(?:\s|$)' })
    $spfRecord = if ($spfAnswers.Count -eq 1) { [string]$spfAnswers[0] } else { $null }
    $spfTerms = if ($spfRecord) { @($spfRecord.Trim() -split '\s+' | Select-Object -Skip 1) } else { @() }
    $spfAllTerms = @($spfTerms | Where-Object { $_ -match '^(?i)[+?~-]?all$' })
    $spfRedirectTerms = @($spfTerms | Where-Object { $_ -match '^(?i)redirect=' })
    $spfOtherTerms = @($spfTerms | Where-Object { $_ -notmatch '^(?i)[+?~-]?all$' -and $_ -notmatch '^(?i)exp=' -and $_ -notmatch '^(?i)redirect=' })
    $spfAllQualifier = if ($spfAllTerms.Count -eq 1) {
        $qualifier = [regex]::Match($spfAllTerms[0], '^(?<qualifier>[+?~-]?)all$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Groups['qualifier'].Value
        if ($qualifier) { $qualifier } else { '+' }
    } else {
        $null
    }
    $spfHardFailAtEnd = $spfRecord -match '(?i)(?:^|\s)-all\s*$'
    $spfDoesNotAuthorizeSenders = $spfAllTerms.Count -eq 1 -and $spfAllQualifier -in @('-', '~', '?') -and $spfOtherTerms.Count -eq 0
    $spfHasSenderMechanisms = $spfRecord -and -not $spfDoesNotAuthorizeSenders -and ($spfOtherTerms.Count -gt 0 -or $spfAllQualifier -eq '+')

    $domainConfigs = @($DkimSigningConfigs | Where-Object {
        $configDomain = $null
        if ($_.PSObject.Properties['Domain']) {
            $configDomain = $_.Domain
        } elseif ($_.PSObject.Properties['Name']) {
            $configDomain = $_.Name
        }
        $configDomain -and [string]::Equals([string]$configDomain, $DomainName, [System.StringComparison]::OrdinalIgnoreCase)
    })
    $dkimLookups = @($lookups.GetEnumerator() | Where-Object { $_.Key -like 'DKIM:*' })
    $hasDkimSelectorRecordEvidence = @($dkimLookups | Where-Object { @($_.Value.Answers).Count -gt 0 }).Count -gt 0
    $hasDkimEvidence = $domainConfigs.Count -gt 0 -or $hasDkimSelectorRecordEvidence
    $unknownDkimLookups = @($dkimLookups | Where-Object { $_.Value.Status -notin @('Success', 'NXDomain') })

    $classification = 'Unknown'
    $reason = 'The DNS evidence does not establish whether the domain sends email.'
    if ($hasDkimEvidence -or $spfHasSenderMechanisms) {
        $classification = 'Sending'
        $reason = 'An Exchange DKIM configuration, a known DKIM selector record, or an SPF mechanism other than -all indicates email-sending use.'
    } elseif ($spfDoesNotAuthorizeSenders -and $unknownDkimLookups.Count -eq 0) {
        $classification = 'NotSending'
        $reason = 'SPF has only a non-authorizing all mechanism and no Exchange DKIM configuration or selector1/selector2 records were found.'

        $mxRecords = @($lookups.MX.Answers)
        $nullMx = $mxRecords.Count -eq 1 -and [string]$mxRecords[0].Value -eq '.' -and [string]$mxRecords[0].Preference -eq '0'
        $hasMx = @($mxRecords | Where-Object { [string]$_.Value -and [string]$_.Value -ne '.' }).Count -gt 0
        $hasAddress = @($lookups.A.Answers).Count -gt 0 -or @($lookups.AAAA.Answers).Count -gt 0
        $hasCname = @($lookups.CNAME.Answers).Count -gt 0
        $receivingLookupsKnown = @($lookups.MX, $lookups.A, $lookups.AAAA, $lookups.CNAME | Where-Object { $_.Status -notin @('Success', 'NXDomain') }).Count -eq 0
        $hasNoMx = $mxRecords.Count -eq 0

        if ($receivingLookupsKnown -and -not $hasMx -and -not $hasAddress -and -not $hasCname -and ($hasNoMx -or $nullMx)) {
            $classification = 'Parked'
            $reason = if ($nullMx) {
                'SPF has only a non-authorizing all mechanism, no DKIM configuration or known selector records exist, and null MX plus no apex address or CNAME records indicates no email or other DNS use.'
            } else {
                'SPF has only a non-authorizing all mechanism, no DKIM configuration or known selector records exist, and no MX, fallback address, or apex CNAME records were found.'
            }
        }
    }

    if ($classification -eq 'Unknown') {
        $failedLookups = @($lookups.GetEnumerator() | Where-Object { $_.Value.Status -notin @('Success', 'NXDomain') })
        if ($failedLookups.Count -gt 0) {
            $reason = "DNS lookup results are incomplete for $($failedLookups.Key -join ', '); the domain is not classified as parked."
        } elseif (-not $spfRecord) {
            $reason = 'A single SPF v1 record was not found; the domain is not classified as parked.'
        } else {
            $reason = 'The SPF and DKIM evidence is conflicting or inconclusive; the domain is not classified as parked.'
        }
    } elseif ($classification -eq 'NotSending') {
        $failedReceivingLookups = @($lookups.MX, $lookups.A, $lookups.AAAA, $lookups.CNAME | Where-Object { $_.Status -notin @('Success', 'NXDomain') })
        if ($failedReceivingLookups.Count -gt 0) {
            $reason += ' Receiving or other domain use could not be ruled out because some DNS lookups failed.'
        } elseif ($hasMx -or $hasAddress -or $hasCname) {
            $reason += ' Receiving or other domain use is present, so the domain is not classified as parked.'
        }
    }

    $isOverride = @($ParkedDomains | Where-Object {
        [string]::Equals($_.TrimEnd('.'), $DomainName.TrimEnd('.'), [System.StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0
    if ($isOverride) {
        $automaticClassification = $classification
        $classification = 'Parked'
        $reason = "The domain was explicitly listed in ParkedDomains. Automatic DNS classification was '$automaticClassification'."
    }

    return [pscustomobject]@{
        DomainName     = $DomainName
        Classification = $classification
        IsParked       = $classification -eq 'Parked'
        IsOverride     = $isOverride
        SpfRecord      = $spfRecord
        SpfDeniesAll   = $spfDoesNotAuthorizeSenders -and $spfAllQualifier -eq '-' -and $spfRedirectTerms.Count -eq 0 -and $spfHardFailAtEnd
        DkimEvidence   = $hasDkimEvidence
        DkimSelectorRecordEvidence = $hasDkimSelectorRecordEvidence
        DkimSelectorLookupsComplete = $unknownDkimLookups.Count -eq 0
        Reason         = $reason
    }
}
