function Test-MtCisDkim {
    <#
    .SYNOPSIS
    Checks DKIM for domains that send email and verifies parked domains have no DKIM records.

    .DESCRIPTION
    Domains require DKIM to be enabled with a valid Exchange status. Domains listed in the ParkedDomains parameter must not publish DKIM records instead. Initial (MOERA) and coexistence domains are excluded, as Microsoft automatically signs outbound mail for those domains.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.9, L1)

    .EXAMPLE
    Test-MtCisDkim

    Returns true if every domain has DKIM enabled with Exchange status Valid, and every domain listed in ParkedDomains has no selector1 or selector2 DKIM record. Initial and coexistence domains are excluded.

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
        Contributor = ('JeanPhilippeGeorge', 'brianreidc7', 'amlhive-tech', 'JeremyFinney-lgtm', 'earbona23', 'merill')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Selector-name for the DKIM record to test..
        [string]$Selector = 'selector1',

        # Domains that are not used to send email. They must not publish DKIM records.
        [string[]]$ParkedDomains = @()
    )

    if (-not $PSBoundParameters.ContainsKey('ParkedDomains')) {
        $ParkedDomains = Get-MtSetting -Name 'ParkedDomains'
    }

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

        if (Test-MtCisParkedDomain -DomainName $domain.DomainName -ParkedDomains $ParkedDomains) {
            # CIS: don't publish DKIM records for a parked domain. Exchange Online uses selector1 and selector2.
            $selectorLookups = foreach ($selectorName in 'selector1', 'selector2') {
                foreach ($recordType in 'CNAME', 'TXT') {
                    Resolve-MtDnsRecord -Name "$selectorName._domainkey.$($domain.DomainName)" -Type $recordType
                }
            }
            $hasSelectorRecord = @($selectorLookups | Where-Object { @($_.Answers).Count -gt 0 }).Count -gt 0
            $incompleteLookups = @($selectorLookups | Where-Object { $_.Status -notin @('Success', 'NXDomain') })
            $resolverUnavailable = @($selectorLookups | Where-Object { $_.Status -ne 'NotAvailable' }).Count -eq 0

            $pass, $reason = if ($hasSelectorRecord) {
                'Failed', 'Listed as parked, but a selector1 or selector2 DKIM record is published. Remove it.'
            } elseif ($resolverUnavailable) {
                'NotSupported', 'Listed as parked, but DNS lookups are not available here, so the DKIM records could not be checked.'
            } elseif ($incompleteLookups.Count -gt 0) {
                'Investigate', 'Listed as parked, but some DKIM selector lookups failed, so it could not be confirmed that no record is published.'
            } else {
                'Passed', 'Listed as parked, and no selector1 or selector2 DKIM record is published.'
            }
            $dkimRecords += [PSCustomObject]@{
                domain         = $domain.DomainName
                classification = 'Parked'
                pass           = $pass
                reason         = $reason
                exchangeStatus = 'Not applicable'
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
                classification = 'Sending'
                pass       = 'Failed'
                reason     = 'No DkimSigningConfig found. Add the domain to ParkedDomains if it does not send email.'
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
        $dkimRecord | Add-Member -MemberType NoteProperty -Name 'classification' -Value 'Sending'

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

    if ($testResult -and ('Investigate' -in $dkimRecords.pass -or 'NotSupported' -in $dkimRecords.pass)) {
        $testResultMarkdown = "Compliance with the applicable CIS DKIM requirement remains unconfirmed. Review the domains marked Investigate or skipped because DNS lookups are unavailable.`n`n%TestResult%"
    }
    elseif ($testResult) {
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

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:(('Investigate' -in $dkimRecords.pass -or 'NotSupported' -in $dkimRecords.pass) -and 'Failed' -notin $dkimRecords.pass)
    return $testResult
}
