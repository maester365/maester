function Test-MtCisDkim {
    <#
    .SYNOPSIS
    Checks DKIM for domains that send email and verifies parked domains have no DKIM records.

    .DESCRIPTION
    Sending domains require DKIM to be enabled with a valid Exchange status. Parked domains must not publish DKIM records. Initial (MOERA) and coexistence domains are excluded, as Microsoft automatically signs outbound mail for those domains. Ambiguous domain-use evidence is reported for investigation.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.9, L1)

    .EXAMPLE
    Test-MtCisDkim

    Returns true if every sending domain has DKIM enabled with Exchange status Valid and every parked domain has no known Exchange selector records. Initial and coexistence domains are excluded. Domains classified as not sending are out of scope; ambiguous domains require investigation.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisDkim
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.9',
        Title = 'Ensure that DKIM is enabled for all Exchange Online Domains',
        Product = 'defender',
        RelatedProduct = 'exchange',
        Feature = 'email-authentication',
        Area = 'email-protection',
        ResourceType = 'Domain',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = ('cis-m365:2.1.9', 'nist-800-53-r5:SC-8'),
        Service = 'ExchangeOnline',
        Author = 'NZLostboy',
        Contributor = ('JeanPhilippeGeorge', 'brianreidc7', 'amlhive-tech', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Selector-name for the DKIM record to test..
        [string]$Selector = 'selector1',

        # Domains explicitly confirmed as parked; any published selector record still fails the audit.
        [string[]]$ParkedDomains = @()
    )

    $dkimSigningConfigs = Get-MtExo -Request DkimSigningConfig
    $acceptedDomains = Get-MtExo -Request AcceptedDomain

    $dkimRecords = @()
    foreach ($domain in $acceptedDomains) {
        if ($domain.InitialDomain -eq $true -or $domain.IsCoExistenceDomain -eq $true) {
            $dkimRecord = [PSCustomObject]@{
                domain     = $domain.DomainName
                classification = 'Excluded'
                pass       = 'Skipped'
                reason     = 'Initial or coexistence domain excluded from DKIM audit (Microsoft auto-signs outbound mail for this domain)'
                exchangeStatus = 'Excluded'
                dkimRecord = $null
            }
            $dkimRecords += $dkimRecord
            continue
        }

        $classification = Get-MtCisParkedDomainClassification -DomainName $domain.DomainName -DkimSigningConfigs $dkimSigningConfigs -ParkedDomains $ParkedDomains
        if ($classification.Classification -eq 'Parked') {
            $hasDkimSelectorRecord = $classification.DkimSelectorRecordEvidence
            $selectorLookupsComplete = $classification.DkimSelectorLookupsComplete
            $dkimRecords += [PSCustomObject]@{
                domain         = $domain.DomainName
                classification = $classification.Classification
                pass           = if ($hasDkimSelectorRecord) { 'Failed' } elseif (-not $selectorLookupsComplete) { 'Investigate' } else { 'Passed' }
                reason         = if ($hasDkimSelectorRecord) { "Parked domain has a published standard DKIM selector record that must be removed. $($classification.Reason)" } elseif (-not $selectorLookupsComplete) { "Standard DKIM selector DNS lookups did not complete, so record absence could not be confirmed. $($classification.Reason)" } else { "Parked domain has no published standard DKIM selector records. $($classification.Reason)" }
                exchangeStatus = if ($selectorLookupsComplete) { 'Not applicable' } else { 'Not determined' }
                dkimRecord     = $null
            }
            continue
        }

        if ($classification.Classification -eq 'NotSending') {
            $dkimRecords += [PSCustomObject]@{
                domain         = $domain.DomainName
                classification = $classification.Classification
                pass           = 'Skipped'
                reason         = "The CIS DKIM audit applies to domains configured to send email. $($classification.Reason)"
                exchangeStatus = 'Not applicable'
                dkimRecord     = $null
            }
            continue
        }

        if ($classification.Classification -eq 'Unknown') {
            if ($classification.DnsResolverUnavailable) {
                $dkimRecords += [PSCustomObject]@{
                    domain         = $domain.DomainName
                    classification = $classification.Classification
                    pass           = 'NotSupported'
                    reason         = "DNS resolver is unavailable, so sending use and selector records cannot be evaluated. $($classification.Reason)"
                    exchangeStatus = 'Not determined'
                    dkimRecord     = $null
                }
                continue
            }

            $dkimRecords += [PSCustomObject]@{
                domain         = $domain.DomainName
                classification = $classification.Classification
                pass           = 'Investigate'
                reason         = "Sending use could not be established; the domain was not classified as parked. $($classification.Reason)"
                exchangeStatus = 'Not determined'
                dkimRecord     = $null
            }
            continue
        }

        $dkimSigningConfig = $dkimSigningConfigs | Where-Object {
            $_.domain -eq $domain.domainname
        }

        if (-not $dkimSigningConfig) {
            $dkimRecord = [PSCustomObject]@{
                domain     = $domain.DomainName
                classification = $classification.Classification
                pass       = 'Failed'
                reason     = 'No DkimSigningConfig found for a domain classified as sending'
                exchangeStatus = 'Not configured'
                dkimRecord = $null
            }
            $dkimRecords += $dkimRecord
            continue
        }

        if ((Get-Date) -gt $dkimSigningConfig.RotateOnDate) {
            if ($Selector -ne $dkimSigningConfig.SelectorAfterRotateOnDate) {
                Write-Verbose "Using DKIM $($dkimSigningConfig.SelectorAfterRotateOnDate) based on EXO config"
            }
            $Selector = $dkimSigningConfig.SelectorAfterRotateOnDate
        } else {
            if ($Selector -ne $dkimSigningConfig.SelectorBeforeRotateOnDate) {
                Write-Verbose "Using DKIM $($dkimSigningConfig.SelectorBeforeRotateOnDate) based on EXO config"
            }
            $selector = $dkimSigningConfig.SelectorBeforeRotateOnDate
        }

        $isMicrosoftDomain = $domain.DomainName.EndsWith(".onmicrosoft.com")
        $isMicrosoftExoHybridDomain = $domain.DomainName.EndsWith(".mail.onmicrosoft.com")
        $dkimDnsName = if ($isMicrosoftExoHybridDomain) {
            "$($Selector)._domainkey.$($domain.DomainName)"
        } elseif ($isMicrosoftDomain) {
            $dkimSigningConfig."$($selector)CNAME"
        } else {
            "$($Selector)._domainkey.$($domain.DomainName)"
        }
        $dkimRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -DkimDnsName $dkimDnsName -Records DKIM
        $dkimRecord | Add-Member -MemberType NoteProperty -Name 'pass' -Value 'Failed'
        $dkimRecord | Add-Member -MemberType NoteProperty -Name 'reason' -Value ''
        $dkimRecord | Add-Member -MemberType NoteProperty -Name 'exchangeStatus' -Value $dkimSigningConfig.Status
        $dkimRecord | Add-Member -MemberType NoteProperty -Name 'classification' -Value $classification.Classification

        if (-not $dkimSigningConfig.enabled) {
            $dkimRecord.pass = 'Failed'
            $dkimRecord.reason = 'DKIM is disabled'
        } elseif ($dkimSigningConfig.Status -ne 'Valid') {
            $dkimRecord.pass = 'Failed'
            $dkimRecord.reason = "Exchange DKIM status is '$($dkimSigningConfig.Status)' (expected Valid)"
        } elseif ($null -ne $dkimRecord.dkimRecord -and $dkimRecord.dkimRecord.GetType().Name -eq 'DKIMRecord') {
            if (-not $dkimRecord.dkimRecord.validBase64) {
                $dkimRecord.reason = 'Malformed public key'
            } else {
                $dkimRecord.pass = 'Passed'
            }
        } elseif ($domain.DomainName -like '*.onmicrosoft.com') {
            $dkimRecord.reason = "Recommendation: Disable sending from domain"
        } elseif ($dkimRecord.dkimRecord -like '*not available') {
            $dkimRecord.pass = 'NotSupported'
            $dkimRecord.reason = $dkimRecord.dkimRecord
        } else {
            $dkimRecord.reason = $dkimRecord.dkimRecord
        }

        $dkimRecords += $dkimRecord
    }

    if ('Failed' -in $dkimRecords.pass) {
        $testResult = $false
    }
    elseif ('Investigate' -in $dkimRecords.pass) {
        $testResult = $true
    }
    elseif ('NotSupported' -in $dkimRecords.pass -and 'Passed' -notin $dkimRecords.pass) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    elseif ('Passed' -notin $dkimRecords.pass) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }
    else {
        $testResult = $true
    }

    $portalLink = 'https://security.microsoft.com/authentication?viewid=DKIM'

    if ($testResult) {
        $testResultMarkdown = "Well done. Sending domains have DKIM configured and valid records exist, and parked domains have no known Exchange selector records.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant's domains do not have DKIM fully deployed. Review [EXO configuration]($portalLink) and DNS records.`n`n%TestResult%"
    }

    $passResult = '✅ Pass'
    $failResult = '❌ Fail'
    $skipResult = '🗄️ Skip'
    $result = "| Domain | Classification | Result | Exchange status | Reason |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach ($item in $dkimRecords | Sort-Object -Property domain) {
        switch ($item.pass) {
            'Passed' { $itemResult = $passResult }
            'Skipped' { $itemResult = $skipResult }
            'NotSupported' { $itemResult = $skipResult }
            'Failed' { $itemResult = $failResult }
            'Investigate' { $itemResult = '🔎 Investigate' }
        }
        $result += "| $($item.domain) | $($item.classification) | $($itemResult) | $($item.exchangeStatus) | $($item.reason) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:('Investigate' -in $dkimRecords.pass -and 'Failed' -notin $dkimRecords.pass)
    return $testResult
}
